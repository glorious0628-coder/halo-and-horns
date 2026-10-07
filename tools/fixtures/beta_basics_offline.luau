-- BB4 "전투력" (one server-computed power number) and BB16 titles ("베타 개척자" / "회색 전설" / TitleSel), run offline.
-- tools/test_beta_basics.py injects the CURRENT repository sources before this file: CONFIG_SOURCE, UTIL_SOURCE,
-- DATA_SOURCE, SET_STAT_SOURCE (PlayerService.SetStat / AddStat), JUSTICE_SOURCE (whole JusticeService), TITLE_SOURCE
-- (whole TitleService) and PVP_POWER_SOURCE (PvPService num / combatPower / BoldMult + the bully weak-victim line).
-- Only engine / service boundaries are doubles: no Studio, no network, no DataStore. Every check is named and collected
-- (a failure never aborts the run); the result is one JSON line.

------------------------------------------------------------------ check collection
local results, order, findings = {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
local groupWarnings = {}
local groupWorlds = {}

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
	groupWorlds = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	for _, w in groupWorlds do
		for _, text in w.Warnings do
			if not (w.AllowWarn and string.find(text, w.AllowWarn, 1, true)) then table.insert(groupWarnings, text) end
		end
	end
	check(#groupWarnings == 0, "no service warnings (pcall-swallowed handler errors)", groupWarnings[1])
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

local function has(text, part)
	return type(text) == "string" and string.find(text, part, 1, true) ~= nil
end

-- plain (non-pattern) replacement of exactly one occurrence; returns the new text and how often `old` occurred
local function replaceOnce(text, old, new)
	local n, from = 0, 1
	while true do
		local s, e = string.find(text, old, from, true)
		if not s then break end
		n += 1
		from = e + 1
	end
	if n ~= 1 then return text, n end
	local s, e = string.find(text, old, 1, true)
	return string.sub(text, 1, s - 1) .. new .. string.sub(text, e + 1), 1
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
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
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

-- an RBXScriptSignal stand-in: handlers run at once, errors are reported (to `sink`) and never reach the firer
local function rbxSignal(sink)
	local list = {}
	local s = {}
	function s:Connect(fn)
		local c = { Fn = fn, Live = true }
		table.insert(list, c)
		return { Disconnect = function()
			c.Live = false
			local i = table.find(list, c)
			if i then table.remove(list, i) end
		end }
	end
	function s:Fire(...)
		for _, c in table.clone(list) do
			if c.Live then
				local ok, err = pcall(c.Fn, ...)
				if not ok then table.insert(sink, "signal handler: " .. tostring(err)) end
			end
		end
	end
	function s:Count() return #list end
	return s
end

local RandomDouble = { new = function()
	local state = 12345
	local r = {}
	local function nextFloat()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	function r:NextNumber(a, b)
		local v = nextFloat()
		if a ~= nil then return a + (b - a) * v end
		return v
	end
	function r:NextInteger(a, b) return math.min(b, a + math.floor(nextFloat() * (b - a + 1))) end
	return r
end }

-- a Player with Roblox-like attributes: GetAttributeChangedSignal fires only when the value really changes.
-- Log keeps every SetAttribute call (key, value) so tests can count writes.
local function newPlayer(w, userId)
	local p = { __kind = "Instance", ClassName = "Player", Name = "P" .. userId, DisplayName = "P" .. userId, UserId = userId,
		Parent = w.Players, Attrs = {}, Signals = {}, Log = {} }
	function p:IsA(kind) return kind == "Player" or kind == "Instance" end
	function p:GetAttribute(k) return self.Attrs[k] end
	function p:SetAttribute(k, v)
		table.insert(self.Log, { Key = k, Value = v })
		if self.Attrs[k] == v then return end
		self.Attrs[k] = v
		local s = self.Signals[k]
		if s then s:Fire() end
	end
	function p:GetAttributeChangedSignal(k)
		self.Signals[k] = self.Signals[k] or rbxSignal(w.Warnings)
		return self.Signals[k]
	end
	function p:Kick(msg) self.Kicked = msg end
	return p
end

local function writes(p, from, key)
	local n, last = 0, nil
	for i = from + 1, #p.Log do
		local e = p.Log[i]
		if e.Key == key then n += 1; last = e.Value end
	end
	return n, last
end

-- attribute-only player for the pure power helpers
local function attrPlayer(attrs)
	local p = { Attrs = attrs or {} }
	function p:GetAttribute(k) return self.Attrs[k] end
	return p
end

------------------------------------------------------------------ server world (real Util, DataService, JusticeService, TitleService)
-- opts: Time (os.time), Rows (shared DataStore rows = the next server of the same game), EditConfig(config)
local W = { Serial = 0, Guid = 0 }
local function newWorld(opts)
	opts = opts or {}
	W.Serial += 1
	local w = { Clock = 1000, Time = opts.Time or (CONFIG.Beta.PioneerUntil - 30 * 86400), Rows = opts.Rows or {}, Deferred = {},
		Spawned = {}, Delayed = {}, Warnings = {}, SetStatLog = {}, Ready = {}, PlayerList = {}, Notices = {} }
	table.insert(groupWorlds, w)
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	if opts.EditConfig then opts.EditConfig(config) end
	w.Config = config
	local players = { __kind = "Instance", ClassName = "Players", Name = "Players" }
	players.PlayerRemoving = rbxSignal(w.Warnings)
	players.PlayerAdded = rbxSignal(w.Warnings)
	function players:GetPlayers()
		local out = {}
		for _, p in w.PlayerList do if p.Parent == players then table.insert(out, p) end end
		return out
	end
	w.Players = players
	local store = {}
	function store:GetAsync(k) return deepCopy(w.Rows[k]) end
	function store:UpdateAsync(k, fn)
		local nextValue = fn(deepCopy(w.Rows[k]))
		if nextValue ~= nil then w.Rows[k] = deepCopy(nextValue) end
		return deepCopy(w.Rows[k])
	end
	local shared = { Config = "Config", Util = "Util", Net = "Net" }
	function shared:WaitForChild(n) return assert(rawget(self, n), "WaitForChild " .. tostring(n)) end
	local replicated = { Shared = shared }
	function replicated:WaitForChild(n) return assert(rawget(self, n), "WaitForChild " .. tostring(n)) end
	local services = {
		Players = players, ReplicatedStorage = replicated,
		DataStoreService = { GetDataStore = function() return store end },
		RunService = { IsStudio = function() return true end, IsServer = function() return true end, IsClient = function() return false end },
		HttpService = { GenerateGUID = function() W.Guid += 1; return "guid-" .. W.Guid end },
	}
	local game = { JobId = "offline-beta-basics", GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	local osDouble = { clock = function() return w.Clock end, time = function() return math.floor(w.Time) end, date = os.date }
	local modules = { Config = config }
	local env = nativeEnv()
	env.game = game
	env.workspace = { GetServerTimeNow = function() return w.Clock end }
	env.typeof = typeofDouble
	env.os = osDouble
	env.Random = RandomDouble
	env.print = function() end
	env.warn = function(...) table.insert(w.Warnings, table.concat({ ... }, " ")) end
	env.task = {
		spawn = function(fn) table.insert(w.Spawned, fn) end,
		wait = function() error("unexpected yield") end,
		delay = function(_, fn) table.insert(w.Delayed, fn) end,
		-- task.defer = end of the frame: queued here and run by w:Flush()
		defer = function(fn, ...) table.insert(w.Deferred, table.pack(fn, ...)) end,
	}
	env.require = function(name) return assert(modules[name], "unexpected require " .. tostring(name)) end
	local function newEnv()
		local e = {}
		for k, v in env do e[k] = v end
		return e
	end

	local util = execute("Util", UTIL_SOURCE, newEnv())
	modules.Util = util
	w.Util = util
	local remotes = {}
	local net = {}
	function net.Get(name)
		if not remotes[name] then
			remotes[name] = { OnServerEvent = rbxSignal(w.Warnings), FireClient = function() end, FireAllClients = function() end }
		end
		return remotes[name]
	end
	local gameState = { Attrs = {} }
	function gameState:SetAttribute(k, v) self.Attrs[k] = v end
	function gameState:GetAttribute(k) return self.Attrs[k] end
	function net.GameState() return gameState end
	function net.Notify(player, text, kind) table.insert(w.Notices, { Player = player, Text = text, Kind = kind }) end
	function net.NotifyAll() end
	function net.Fx() end
	modules.Net = net
	w.Remotes = remotes

	local ds = execute("DataService", DATA_SOURCE, newEnv())
	ds.Init({})
	ds.Start()
	w.Spawned[1]() -- the DataStore probe; the autosave loop is never started
	w.Spawned = {}
	w.DS = ds

	-- PlayerService double (ready set, signals like the real one: Util.Signal) + the real SetStat / AddStat
	local mirrored = {}
	for _, key in config.Data.Mirrored do mirrored[key] = true end
	w.Mirrored = mirrored
	local ps = { PlayerReady = util.Signal.new(), PlayerLeaving = util.Signal.new(), CharacterSpawned = util.Signal.new() }
	ps.IsReady = function(p) return p ~= nil and w.Ready[p] == true end
	ps.GetData = function(p) return ds.Get(p) end
	ps.GetReadyPlayers = function()
		local out = {}
		for _, p in w.PlayerList do if w.Ready[p] then table.insert(out, p) end end
		return out
	end
	ps.RefreshCharacter = function() end
	local real = execute("PlayerService.SetStat", SET_STAT_SOURCE, newEnv(), { DataService = ds }, mirrored)
	ps.SetStat = function(p, key, value)
		table.insert(w.SetStatLog, { Player = p, Key = key, Value = value })
		return real.SetStat(p, key, value)
	end
	ps.AddStat = real.AddStat
	w.PS = ps

	local registry = { PlayerService = ps, DataService = ds }
	local justice = execute("JusticeService", JUSTICE_SOURCE, newEnv())
	local title = execute("TitleService", TITLE_SOURCE, newEnv())
	w.Justice, w.Title, w.Registry = justice, title, registry
	-- Main.server.luau INIT_ORDER: JusticeService ... TitleService
	justice.Init(registry)
	title.Init(registry)
	-- START_ORDER: JusticeService ... LootService ... TitleService. LootService double: what the real one does with the
	-- equipped +N attribute (PlayerReady publish, then WeaponTier change -> WeaponEnhance at once)
	justice.Start()
	local function enhanceOf(data, tier)
		local t = type(data.WeaponEnhance) == "table" and data.WeaponEnhance or {}
		return tonumber(t[tier]) or 0
	end
	ps.PlayerReady:Connect(function(player, data)
		player:SetAttribute("WeaponEnhance", enhanceOf(data, math.floor(tonumber(data.WeaponTier) or 1)))
		player:GetAttributeChangedSignal("WeaponTier"):Connect(function()
			local d = ds.Get(player)
			if d then player:SetAttribute("WeaponEnhance", enhanceOf(d, math.floor(tonumber(d.WeaponTier) or 1))) end
		end)
	end)
	title.Start()
	w.Spawned = {} -- the Justice recompute / scale / decay loops are never started

	-- run every queued task.defer (end of frame); returns how many ran
	function w:Flush()
		local ran = 0
		while #self.Deferred > 0 do
			local list = self.Deferred
			self.Deferred = {}
			for _, job in list do
				ran += 1
				job[1](table.unpack(job, 2, job.n))
			end
		end
		return ran
	end
	function w:Key(userId) return config.Data.KeyPrefix .. tostring(userId) end
	function w:Row(userId) return self.Rows[self:Key(userId)] end
	-- what PlayerService does on join: load, mirror (non-table values), ready, DataLoaded, PlayerReady
	function w:Join(userId)
		local p = newPlayer(self, userId)
		table.insert(self.PlayerList, p)
		local data = assert(ds.Load(p), "DataService.Load failed")
		for _, key in config.Data.Mirrored do
			local v = data[key]
			if v ~= nil and type(v) ~= "table" then p:SetAttribute(key, v) end
		end
		self.Ready[p] = true
		p:SetAttribute("DataLoaded", true)
		ps.PlayerReady:Fire(p, data)
		return p, data
	end
	-- Players.PlayerRemoving -> PlayerService.FinalizeLeave: PlayerLeaving, not ready, final save; `between` runs after
	-- PlayerLeaving while the Player is still parented (the real final save yields there)
	function w:Leave(p, between)
		players.PlayerRemoving:Fire(p)
		ps.PlayerLeaving:Fire(p, ds.Get(p))
		if between then between(p) end
		self.Ready[p] = nil
		ds.Release(p)
		p.Parent = nil
		local i = table.find(self.PlayerList, p)
		if i then table.remove(self.PlayerList, i) end
	end
	function w:SetTitle(p, ...) remotes.SetTitle.OnServerEvent:Fire(p, ...) end
	function w:TitleCalls(p, from)
		local n = 0
		for i = (from or 0) + 1, #self.SetStatLog do
			local e = self.SetStatLog[i]
			if e.Player == p and e.Key == "TitleSel" then n += 1 end
		end
		return n
	end
	w:Flush() -- JusticeService.Start's first recompute
	return w
end

local function row(extra)
	local r = { Version = 3, Level = 10, Faction = "Halo", ClassChosen = true, Class = "Warrior", TutorialStep = 99,
		BlacksmithVisited = true, WeaponTier = 1, WeaponOwnedMask = 1 }
	for k, v in extra or {} do r[k] = v end
	return r
end

local C = CONFIG
local UNTIL = C.Beta.PioneerUntil

------------------------------------------------------------------ A1. CombatPower samples / MaxCombatPower
runGroup("power-samples", function()
	local samples = {
		{ 1, 0, 0, 0, "Lv1 bare hands (A23-34: a new player starts at 0)" },
		{ 2, 0, 0, 12, "Lv2 bare hands (levels still add a little)" },
		{ 1, 1, 0, 283, "Lv1 tier 1 (the M1_1 blacksmith gift)" },
		{ 1, 2, 0, 387, "Lv1 wood weapon (tier 2, bought with the first 150 gold)" },
		{ 5, 3, 0, 758, "Lv5 iron weapon" },
		{ 10, 3, 3, 1052, "Lv10 iron weapon +3" },
		{ 20, 5, 0, 2829, "Lv20 tier 5" },
		{ 1, 8, 0, 872, "Lv1 jelly legendary (tier 8)" },
		{ 1, 4, 0, 938, "Lv1 tier 4" },
	}
	for _, s in samples do
		local got = C.CombatPower(s[1], s[2], s[3])
		check(got == s[4], string.format("CombatPower(%d, %d, %d) = %d (%s)", s[1], s[2], s[3], s[4], s[5]), got)
	end
	check(C.CombatPower(1, 8, 0) < C.CombatPower(1, 4, 0),
		"Lv1 jelly legendary 872 < Lv1 tier 4 938 (weapons count by damage, not by tier index)")
	-- the spec lists 387 without a label: every (level, tier, +N) that gives exactly 387
	local hits = {}
	for level = 1, C.Levels.MaxLevel do
		for tier = 1, C.MaxWeaponTier do
			for e = 0, C.Loot.MaxEnhance do
				if C.CombatPower(level, tier, e) == 387 then table.insert(hits, string.format("Lv%d tier %d +%d", level, tier, e)) end
			end
		end
	end
	check(hits[1] == "Lv1 tier 2 +0", "the spec's 387 is Lv1 tier 2 (wood weapon) +0", table.concat(hits, ", "))
	finding("BB4 sample 387 = " .. table.concat(hits, " or ") .. " (the spec does not label it; the test pins Lv1 tier 2 +0, "
		.. "the wood weapon bought with the first 150-gold mission reward).")
	-- formula: math.floor(PowerOf(level, tier, 1, enhance) x DisplayScale + 0.5), integer, no rebirth multiplier
	check(C.Power.DisplayScale == 10, "Config.Power.DisplayScale = 10", C.Power.DisplayScale)
	local bad = 0
	for _, level in { 1, 2, 7, 9, 10, 33, 64, 99, 100 } do
		for tier = 1, C.MaxWeaponTier do
			for e = 0, C.Loot.MaxEnhance do
				local want = math.floor(C.PowerOf(level, tier, 1, e) * 10 + 0.5)
				local got = C.CombatPower(level, tier, e)
				if got ~= want or got % 1 ~= 0 then
					bad += 1
					if bad <= 2 then check(false, "CombatPower formula sample", show({ level, tier, e, got, want })) end
				end
			end
		end
	end
	check(bad == 0, "CombatPower = floor(PowerOf(level, tier, 1, +N) x 10 + 0.5), an integer", bad)
	check(C.CombatPower(20, 3, nil) == C.CombatPower(20, 3, 0) and C.CombatPower(20, 3, 15) == C.CombatPower(20, 3, 10),
		"missing +N = +0, above +10 counts as +10")
	-- MaxCombatPower: fresh Config (no cache yet)
	local fresh = execute("Config", CONFIG_SOURCE, nativeEnv())
	check(fresh.Power.MaxCache == nil, "no cached maximum before the first call", fresh.Power.MaxCache)
	local m = fresh.MaxCombatPower()
	check(m == 25488, "MaxCombatPower() = 25,488", m)
	check(fresh.Power.MaxCache == m, "the maximum is cached in Config.Power.MaxCache", fresh.Power.MaxCache)
	fresh.Power.MaxCache = 12345
	check(fresh.MaxCombatPower() == 12345, "a second call returns the cached value (no recompute)", fresh.MaxCombatPower())
	local bestTier = 1
	for t = 1, C.MaxWeaponTier do
		if C.Weapons[t].Damage > C.Weapons[bestTier].Damage then bestTier = t end
	end
	check(m == C.CombatPower(C.Levels.MaxLevel, bestTier, C.Loot.MaxEnhance),
		"maximum = Lv100 + the highest-DAMAGE weapon at +10", show({ m, bestTier }))
	local wrong = C.CombatPower(C.Levels.MaxLevel, C.MaxWeaponTier, C.Loot.MaxEnhance)
	check(wrong == 7027 and wrong < m, "the tier-index cap (MaxWeaponTier = jelly legendary) would give 7,027", wrong)
	local over = 0
	for level = 1, C.Levels.MaxLevel do
		for tier = 1, C.MaxWeaponTier do
			for e = 0, C.Loot.MaxEnhance do
				if C.CombatPower(level, tier, e) > m then over += 1 end
			end
		end
	end
	check(over == 0, "no level / weapon / +N goes above MaxCombatPower", over)
end)

------------------------------------------------------------------ A2. monotonic in level, +N and weapon damage
runGroup("power-monotonic", function()
	local levelBad, enhBad = 0, 0
	for tier = 1, C.MaxWeaponTier do
		for e = 0, C.Loot.MaxEnhance do
			local prev = -1
			for level = 1, C.Levels.MaxLevel do
				local v = C.CombatPower(level, tier, e)
				if v <= prev then levelBad += 1 end
				prev = v
			end
		end
		for level = 1, C.Levels.MaxLevel do
			local prev = -1
			for e = 0, C.Loot.MaxEnhance do
				local v = C.CombatPower(level, tier, e)
				if v <= prev then enhBad += 1 end
				prev = v
			end
		end
	end
	check(levelBad == 0, "Lv1 -> Lv100 always raises the number (every weapon, every +N)", levelBad)
	check(enhBad == 0, "+0 -> +10 always raises the number (every weapon, every level)", enhBad)
	-- weapons sorted by Config.Weapons[t].Damage (ties keep the tier order)
	local byDamage = {}
	for t = 1, C.MaxWeaponTier do table.insert(byDamage, t) end
	table.sort(byDamage, function(a, b)
		local da, db = C.Weapons[a].Damage, C.Weapons[b].Damage
		if da ~= db then return da < db end
		return a < b
	end)
	local orderBad = 0
	for level = 1, C.Levels.MaxLevel do
		for _, e in { 0, 3, 10 } do
			for i = 1, #byDamage - 1 do
				local a, b = byDamage[i], byDamage[i + 1]
				local va, vb = C.CombatPower(level, a, e), C.CombatPower(level, b, e)
				if vb < va or (C.Weapons[b].Damage > C.Weapons[a].Damage and vb <= va) then orderBad += 1 end
			end
		end
	end
	check(orderBad == 0, "ordered by weapon Damage the number never goes down (strictly up when Damage is higher)", orderBad)
	check(byDamage[#byDamage] == 7 and byDamage[4] == 8 and byDamage[5] == 4,
		"damage order: tier 8 (76) sits between tier 3 (38) and tier 4 (88); tier 7 is the strongest", show(byDamage))
	check(C.CombatPower(1, 8, 0) < C.CombatPower(1, 7, 0), "tier index order is NOT the power order (tier 8 < tier 7)")
end)

------------------------------------------------------------------ A3. Power.Text and Bully.Text
runGroup("power-text", function()
	local T = C.Power.Text
	for _, k in { "Label", "LabelEn", "Up", "UpEn", "Change", "ChangeEn", "Formula", "FormulaEn", "PvPNote", "PvPNoteEn" } do
		check(type(T[k]) == "string" and T[k] ~= "", "Config.Power.Text." .. k .. " is a non-empty string", show(T[k]))
	end
	check(T.Label == "Power" and T.LabelEn == "Power", "Label / LabelEn = Power (A23-48 English)", show({ T.Label, T.LabelEn }))
	local okUp, up = pcall(string.format, T.Up, "1,052")
	local okUpEn, upEn = pcall(string.format, T.UpEn, "1,052")
	check(okUp and up == "Power +1,052" and okUpEn and upEn == "Power +1,052", "Up / UpEn format one number",
		show({ up, upEn }))
	local okCh, ch = pcall(string.format, T.Change, "283", "387")
	local okChEn, chEn = pcall(string.format, T.ChangeEn, "283", "387")
	check(okCh and has(ch, "283") and has(ch, "387") and okChEn and has(chEn, "283") and has(chEn, "387"),
		"Change / ChangeEn format (old, new)", show({ ch, chEn }))
	-- PvPNote / PvPNoteEn are finished sentences, built in Config right after Config.PvP: the caller shows them as they
	-- are (no string.format), so no '%' may be left and the real PowerRatioMax / PowerRatioMin numbers must be inside
	local hi, lo = tostring(C.PvP.PowerRatioMax), tostring(C.PvP.PowerRatioMin)
	for _, k in { "PvPNote", "PvPNoteEn" } do
		local note = T[k]
		check(type(note) == "string" and not string.find(note, "%", 1, true),
			k .. " is a finished line: a string with no '%' at all (no template left for the caller)", show(note))
		check(has(note, hi) and has(note, lo),
			k .. " contains the real Config.PvP.PowerRatioMax and PowerRatioMin numbers", show({ note, hi, lo }))
	end
	check(has(T.PvPNote, "at most x" .. hi) and has(T.PvPNote, "at least x" .. lo),
		"PvPNote reads at most x<PowerRatioMax>, at least x<PowerRatioMin>", show({ T.PvPNote, hi, lo }))
	-- review 2026-10-06 (B6): the WHOLE finished sentences, not only containment, so a swapped max/min order (numbers or
	-- the most/least words) fails. A23-48: the game is English only, so PvPNote is the same English line as PvPNoteEn.
	local NOTE = {
		En = "However strong the weapons, PvP damage is at most x%s and at least x%s",
	}
	local wantEn = string.format(NOTE.En, hi, lo)
	check(T.PvPNote == wantEn,
		"PvPNote is exactly the finished English sentence (A23-48: the same line as PvPNoteEn)",
		show({ got = T.PvPNote, want = wantEn }))
	check(T.PvPNoteEn == wantEn,
		"PvPNoteEn is exactly the finished EN sentence 'However strong the weapons, PvP damage is at most x<Max> and at least x<Min>'",
		show({ got = T.PvPNoteEn, want = wantEn }))
	-- built from Config.PvP, not typed in: other numbers -> other lines (numbers replaced whatever they are now)
	local pvpSrc, p1 = string.gsub(CONFIG_SOURCE, "PowerRatioMin = [%d%.]+,", "PowerRatioMin = 0.65,")
	local p2
	pvpSrc, p2 = string.gsub(pvpSrc, "PowerRatioMax = [%d%.]+,", "PowerRatioMax = 1.35,")
	check(p1 == 1 and p2 == 1, "Config.PvP PowerRatioMin / PowerRatioMax lines found once each (fixture probe)", show({ p1, p2 }))
	local altText = execute("Config", pvpSrc, nativeEnv()).Power.Text
	for _, k in { "PvPNote", "PvPNoteEn" } do
		local note = altText[k]
		check(has(note, "1.35") and has(note, "0.65") and not has(note, "%"),
			k .. " follows Config.PvP.PowerRatioMax / PowerRatioMin (finished line, no '%')", show(note))
	end
	check(altText.PvPNote == string.format(NOTE.En, "1.35", "0.65")
		and altText.PvPNoteEn == string.format(NOTE.En, "1.35", "0.65"),
		"PvPNote / PvPNoteEn with Max 1.35 / Min 0.65 are exactly the finished English sentences (max first, min second)",
		show({ altText.PvPNote, altText.PvPNoteEn }))
	-- Bully.Text
	local B = C.Bully.Text
	check(type(B) == "table" and type(B.Title) == "string" and B.Title ~= "" and type(B.TitleEn) == "string" and B.TitleEn ~= "",
		"Bully.Text Title / TitleEn", show(B and { B.Title, B.TitleEn }))
	check(type(B.Lines) == "table" and #B.Lines == 3 and type(B.LinesEn) == "table" and #B.LinesEn == 3,
		"Bully.Text has 3 Lines and 3 LinesEn", show(B.Lines))
	check(C.Bully.WeakPowerRatio == 0.5 and C.Bully.FreshSpawnSeconds == 15 and C.Bully.RepeatKOs == 3 and C.Bully.RepeatWindow == 600,
		"Config.Bully numbers 0.5 / 15 s / 3 KOs / 600 s")
	for _, list in { B.Lines, B.LinesEn } do
		check(has(list[1], "50"), "line 1 (weak victim) says 50%", list[1])
		check(has(list[2], "15"), "line 2 (fresh respawn) says 15 s", list[2])
		check(has(list[3], "3") and has(list[3], "10"), "line 3 (repeat KOs) says 3 times / 10 minutes", list[3])
	end
	check(has(B.Lines[1], "50%") and has(B.Lines[2], "15 s") and has(B.Lines[3], "3 times") and has(B.Lines[3], "10 minutes"),
		"English lines (A23-48): 50% / 15 s / 3 times / 10 minutes", show(B.Lines))
	-- the lines are built from Config.Bully (string.format), not typed in: other numbers -> other lines
	local src, n1, n2, n3, n4 = CONFIG_SOURCE, 0, 0, 0, 0
	src, n1 = replaceOnce(src, "WeakPowerRatio = 0.5,", "WeakPowerRatio = 0.25,")
	src, n2 = replaceOnce(src, "FreshSpawnSeconds = 15,", "FreshSpawnSeconds = 12,")
	src, n3 = replaceOnce(src, "RepeatKOs = 3,", "RepeatKOs = 4,")
	src, n4 = replaceOnce(src, "RepeatWindow = 600,", "RepeatWindow = 1200,")
	check(n1 == 1 and n2 == 1 and n3 == 1 and n4 == 1, "Config.Bully number lines found once each (fixture probe)", show({ n1, n2, n3, n4 }))
	local alt = execute("Config", src, nativeEnv())
	local A = alt.Bully.Text
	for _, list in { A.Lines, A.LinesEn } do
		check(has(list[1], "25") and not has(list[1], "50"), "line 1 follows WeakPowerRatio", list[1])
		check(has(list[2], "12") and not has(list[2], "15"), "line 2 follows FreshSpawnSeconds", list[2])
		check(has(list[3], "4") and has(list[3], "20") and not has(list[3], "10"), "line 3 follows RepeatKOs / RepeatWindow", list[3])
	end
end)

------------------------------------------------------------------ B1. JusticeService.GetCombatPower (real service)
runGroup("justice-getcombatpower", function()
	local w = newWorld()
	local J = w.Justice
	for _, s in { { 1, 1, 0, 283 }, { 1, 2, 0, 387 }, { 5, 3, 0, 758 }, { 10, 3, 3, 1052 }, { 20, 5, 0, 2829 } } do
		local got = J.GetCombatPower(attrPlayer({ Level = s[1], WeaponTier = s[2], WeaponEnhance = s[3] }))
		check(got == s[4], "GetCombatPower reads Level / WeaponTier / WeaponEnhance = Config.CombatPower", show({ s, got }))
	end
	local plain = attrPlayer({ Level = 10, WeaponTier = 3, WeaponEnhance = 3 })
	local reborn = attrPlayer({ Level = 10, WeaponTier = 3, WeaponEnhance = 3, RebirthBonus = 0.75, Rebirths = 3 })
	check(J.GetCombatPower(reborn) == 1052 and J.GetCombatPower(reborn) == J.GetCombatPower(plain),
		"no rebirth bonus in the combat power", J.GetCombatPower(reborn))
	check(J.GetPower(reborn) > J.GetPower(plain) and math.abs(J.GetPower(reborn) - C.PowerOf(10, 3, 1.75, 3)) < 1e-9,
		"GetPower (faction power) stays as it was: rebirth bonus included", show({ J.GetPower(reborn), J.GetPower(plain) }))
	check(J.GetCombatPower(attrPlayer({})) == 0, "missing attributes = Lv1 bare hands = 0 (A23-34)", J.GetCombatPower(attrPlayer({})))
	check(J.GetCombatPower(attrPlayer({ Level = 0, WeaponTier = 99, WeaponEnhance = 99 }))
		== C.CombatPower(1, C.MaxWeaponTier, C.Loot.MaxEnhance), "level floor 1, tier clamped to MaxWeaponTier, +N clamped to +10")
	check(J.GetCombatPower(nil) == 0, "nil player -> 0")
	local v = J.GetCombatPower(attrPlayer({ Level = 37, WeaponTier = 6, WeaponEnhance = 7 }))
	check(type(v) == "number" and v % 1 == 0, "an integer", v)
end)

------------------------------------------------------------------ B2. the CombatPower attribute (real Init / Start wiring)
runGroup("justice-attribute", function()
	local w = newWorld()
	local uid = 9101
	w.Rows[w:Key(uid)] = row({ Level = 10, WeaponTier = 3, WeaponOwnedMask = 7, WeaponEnhance = { 0, 0, 3 } })
	local p = w:Join(uid)
	-- set by the PlayerReady handler itself (before any deferred work)
	local first = p:GetAttribute("CombatPower")
	check(first ~= nil, "CombatPower attribute is set on PlayerReady (before the frame ends)", first)
	check(first == C.CombatPower(10, 3, 0) or first == C.CombatPower(10, 3, 3), "the PlayerReady value is a Config.CombatPower",
		first)
	local joinWrites = writes(p, 0, "CombatPower")
	w:Flush()
	check(p:GetAttribute("CombatPower") == 1052, "after the join frame: Lv10 iron +3 = 1,052 (WeaponEnhance from the save)",
		p:GetAttribute("CombatPower"))
	local totalJoin = writes(p, 0, "CombatPower")
	finding(string.format("Join of a Lv10 iron +3 player: %d CombatPower write(s) inside PlayerReady (%s, the WeaponEnhance "
		.. "attribute is not set yet because JusticeService connects PlayerReady at Init, LootService at Start) and %d in "
		.. "total once the frame's deferred refresh ran (final %s). Same frame, so the client normally sees only the last value.",
		joinWrites, tostring(first), totalJoin, tostring(p:GetAttribute("CombatPower"))))

	-- equip: WeaponTier then WeaponEnhance (LootService order) in one frame -> exactly one change
	local m = #p.Log
	w.PS.SetStat(p, "WeaponTier", 1)
	check(writes(p, m, "CombatPower") == 0, "equip: no CombatPower write before the frame ends (task.defer)", writes(p, m, "CombatPower"))
	w:Flush()
	local n, last = writes(p, m, "CombatPower")
	check(n == 1 and last == C.CombatPower(10, 1, 0), "equip tier 3 +3 -> tier 1 +0: exactly one CombatPower write", show({ n, last }))
	m = #p.Log
	w.PS.SetStat(p, "WeaponTier", 3)
	w:Flush()
	n, last = writes(p, m, "CombatPower")
	check(n == 1 and last == 1052, "equip tier 1 +0 -> tier 3 +3: exactly one CombatPower write", show({ n, last }))
	-- Level + WeaponTier + WeaponEnhance in the same frame -> one write
	m = #p.Log
	w.PS.SetStat(p, "Level", 11)
	w.DS.Get(p).WeaponEnhance[1] = 2
	w.PS.SetStat(p, "WeaponTier", 1)
	w:Flush()
	n, last = writes(p, m, "CombatPower")
	check(n == 1 and last == C.CombatPower(11, 1, 2), "level-up + equip in one frame: one write", show({ n, last }))
	-- a scroll changes only WeaponEnhance -> one write
	m = #p.Log
	w.DS.Get(p).WeaponEnhance[1] = 3
	p:SetAttribute("WeaponEnhance", 3)
	w:Flush()
	n, last = writes(p, m, "CombatPower")
	check(n == 1 and last == C.CombatPower(11, 1, 3), "enhance scroll (WeaponEnhance only): one write", show({ n, last }))
	-- level only -> one write
	m = #p.Log
	w.PS.SetStat(p, "Level", 12)
	w:Flush()
	n, last = writes(p, m, "CombatPower")
	check(n == 1 and last == C.CombatPower(12, 1, 3), "level-up only: one write", show({ n, last }))
	-- rebirth bonus / honor change nothing
	m = #p.Log
	w.PS.SetStat(p, "RebirthBonus", 0.5)
	w.PS.SetStat(p, "Rebirths", 2)
	w.PS.SetStat(p, "Honor", 40)
	w:Flush()
	check(writes(p, m, "CombatPower") == 0, "RebirthBonus / Rebirths / Honor never touch CombatPower", writes(p, m, "CombatPower"))
	-- +10 -> +12 (clamped, same number): no write
	p:SetAttribute("WeaponEnhance", 10)
	w:Flush()
	m = #p.Log
	p:SetAttribute("WeaponEnhance", 12)
	w:Flush()
	check(writes(p, m, "CombatPower") == 0 and p:GetAttribute("CombatPower") == C.CombatPower(12, 1, 10),
		"a change that keeps the number (+10 -> +12 clamps) writes nothing", writes(p, m, "CombatPower"))
	-- two players in one frame: one write each
	local uid2 = 9102
	w.Rows[w:Key(uid2)] = row({ Level = 3 })
	local q = w:Join(uid2)
	w:Flush()
	local mp, mq = #p.Log, #q.Log
	w.PS.SetStat(p, "Level", 13)
	w.PS.SetStat(q, "Level", 4)
	p:SetAttribute("WeaponEnhance", 4)
	w:Flush()
	check(writes(p, mp, "CombatPower") == 1 and writes(q, mq, "CombatPower") == 1, "two players changed in one frame: one write each",
		show({ writes(p, mp, "CombatPower"), writes(q, mq, "CombatPower") }))
	check(p:GetAttribute("CombatPower") == C.CombatPower(13, 1, 4) and q:GetAttribute("CombatPower") == C.CombatPower(4, 1, 0),
		"each player keeps their own number")
	check(p.Signals.Level:Count() >= 1 and p.Signals.WeaponEnhance:Count() == 1, "while in game: Level / WeaponEnhance watched",
		show({ p.Signals.Level:Count(), p.Signals.WeaponEnhance:Count() }))

	-- leaving: a refresh queued in the leave frame and changes after PlayerLeaving never write; connections dropped
	m = #p.Log
	w.PS.SetStat(p, "WeaponTier", 3)
	w:Leave(p, function(pl)
		pl:SetAttribute("Level", 50)
		pl:SetAttribute("WeaponEnhance", 9)
		w:Flush()
	end)
	w:Flush()
	check(writes(p, m, "CombatPower") == 0, "no CombatPower write after PlayerLeaving (pending refresh dropped)",
		show({ writes(p, m, "CombatPower") }))
	check(p.Signals.Level:Count() == 0 and p.Signals.WeaponEnhance:Count() == 0,
		"PlayerLeaving disconnects the Level / WeaponEnhance watchers", show({ p.Signals.Level:Count(), p.Signals.WeaponEnhance:Count() }))
	-- the other player still updates
	mq = #q.Log
	w.PS.SetStat(q, "Level", 5)
	w:Flush()
	check(writes(q, mq, "CombatPower") == 1 and q:GetAttribute("CombatPower") == C.CombatPower(5, 1, 0), "another player is unaffected")

	-- rejoin on the next server (same rows): the saved level / weapon give the number again
	local w2 = newWorld({ Rows = w.Rows })
	local again = w2:Join(uid)
	w2:Flush()
	local d = w2.DS.Get(again)
	check(again:GetAttribute("CombatPower") == C.CombatPower(d.Level, d.WeaponTier, (d.WeaponEnhance or {})[d.WeaponTier] or 0),
		"rejoin: CombatPower from the saved Level / WeaponTier / +N", show({ again:GetAttribute("CombatPower"), d.Level, d.WeaponTier }))
end)

------------------------------------------------------------------ B3. PvPService combatPower / BoldMult / bully weak test
runGroup("pvp-power", function()
	local P = execute("PvPService power", PVP_POWER_SOURCE, {}, C)
	local function fixed(n)
		local p = attrPlayer({})
		p.Power = n
		return p
	end
	local S1 = { JusticeService = { GetCombatPower = function(p) return p.Power end }, PlayerService = { GetData = function() return nil end } }
	local cases = {
		{ 1000, 1200, 2, "victim 120% -> x2" }, { 1000, 1199, 1, "victim 119.9% -> x1" }, { 1000, 1000, 1, "equal -> x1" },
		{ 1000, 800, 1, "victim exactly 80% -> x1" }, { 1000, 799, 0.5, "victim 79.9% -> x0.5" }, { 1000, 5000, 2, "much stronger -> x2" },
		{ 0, 500, 1, "killer power 0 -> x1" }, { 0 / 0, 500, 1, "NaN -> x1" }, { 1000, 0 / 0, 1, "NaN victim -> x1" },
	}
	for _, c in cases do
		local got = P.BoldMult(fixed(c[1]), fixed(c[2]), S1)
		check(got == c[3], "BoldMult " .. c[4], show({ c[1], c[2], got }))
	end
	check(C.PvP.BoldStrongRatio == 1.2 and C.PvP.BoldWeakRatio == 0.8 and C.PvP.BoldStrongMult == 2 and C.PvP.BoldWeakMult == 0.5,
		"Config.PvP boldness 1.2 / 0.8 / x2 / x0.5")
	check(P.Weak(fixed(1000), fixed(500), S1) == false, "bully: victim exactly 50% is NOT weak")
	check(P.Weak(fixed(1000), fixed(499), S1) == true, "bully: victim below 50% is weak")
	check(P.Weak(fixed(283), fixed(141), S1) == true and P.Weak(fixed(283), fixed(142), S1) == false,
		"bully: 141 < 141.5 weak, 142 not (displayed integers)")
	-- A23-69: the fallback without JusticeService is the one power formula, Config.CombatPowerOf: the mirrored attributes
	-- (Level / WeaponTier mirror the save; WeaponEnhance is the equipped weapon's +N, the save keeps a per-tier table)
	local p = attrPlayer({ WeaponEnhance = 3, Level = 10, WeaponTier = 3 })
	p.Data = { Level = 99, WeaponTier = 7, WeaponEnhance = { 9, 9, 9 } }
	local S0 = { PlayerService = { GetData = function(pl) return pl.Data end } }
	check(P.combatPower(p, S0) == 1052 and P.combatPower(p, S0) == C.CombatPowerOf(p),
		"fallback = Config.CombatPowerOf (the Level / WeaponTier / WeaponEnhance attributes, never the save table)", P.combatPower(p, S0))
	local q = attrPlayer({ Level = 20, WeaponTier = 5, WeaponEnhance = 0 })
	check(P.combatPower(q, S0) == 2829, "fallback without data reads the attributes", P.combatPower(q, S0))
	local r = attrPlayer({ Level = 0, WeaponTier = 99 })
	check(P.combatPower(r, S0) == C.CombatPower(1, C.MaxWeaponTier, 0), "fallback clamps level >= 1 and the tier", P.combatPower(r, S0))
	local broken = { PlayerService = S0.PlayerService, JusticeService = { GetCombatPower = function() error("boom") end } }
	check(P.combatPower(p, broken) == 1052, "a failing JusticeService.GetCombatPower falls back to Config.CombatPower")
	local odd = { PlayerService = S0.PlayerService, JusticeService = { GetCombatPower = function() return "big" end } }
	check(P.combatPower(p, odd) == 1052, "a non-number from JusticeService falls back")
	local viaJ = { PlayerService = S0.PlayerService, JusticeService = { GetCombatPower = function() return 777 end } }
	check(P.combatPower(p, viaJ) == 777, "JusticeService.GetCombatPower wins when it works")

	-- real JusticeService: the server's bully / boldness decisions equal the ones computed from the displayed numbers
	local w = newWorld()
	local S = { JusticeService = w.Justice, PlayerService = { GetData = function() return nil end } }
	local combos = {}
	for _, level in { 1, 2, 3, 5, 8, 10, 15, 20, 30, 50, 75, 100 } do
		for tier = 1, C.MaxWeaponTier do
			for _, e in { 0, 3, 10 } do
				table.insert(combos, attrPlayer({ Level = level, WeaponTier = tier, WeaponEnhance = e,
					RebirthBonus = (#combos % 2 == 0) and 0.4 or 0 }))
			end
		end
	end
	local screen = {}
	for i, pl in combos do
		screen[i] = C.CombatPower(pl.Attrs.Level, pl.Attrs.WeaponTier, pl.Attrs.WeaponEnhance)
	end
	local boldBad, weakBad, floatDiffers = 0, 0, 0
	for i, k in combos do
		for j, v in combos do
			local ratio = screen[j] / screen[i]
			local wantBold = ratio >= 1.2 and 2 or (ratio < 0.8 and 0.5 or 1)
			if P.BoldMult(k, v, S) ~= wantBold then boldBad += 1 end
			if P.Weak(k, v, S) ~= (screen[j] < 0.5 * screen[i]) then weakBad += 1 end
			local fr = C.PowerOf(v.Attrs.Level, v.Attrs.WeaponTier, 1, v.Attrs.WeaponEnhance)
				/ C.PowerOf(k.Attrs.Level, k.Attrs.WeaponTier, 1, k.Attrs.WeaponEnhance)
			local floatBold = fr >= 1.2 and 2 or (fr < 0.8 and 0.5 or 1)
			if floatBold ~= wantBold then floatDiffers += 1 end
		end
	end
	check(boldBad == 0, "BoldMult (server) = x2 / x1 / x0.5 from the displayed CombatPower numbers (rebirth ignored)", boldBad)
	check(weakBad == 0, "bully weak test (server) = displayed victim < 50% of displayed killer", weakBad)
	finding(string.format("Boldness over %d x %d sampled pairs: %d pairs would change multiplier if the unrounded PowerOf were "
		.. "compared instead of the displayed integer.", #combos, #combos, floatDiffers))
end)

------------------------------------------------------------------ C1. title config + data contract
local function utcStamp(y, m, d, hh)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return (era * 146097 + doe - 719468) * 86400 + hh * 3600
end

runGroup("title-config", function()
	check(type(C.TitleDefs) == "table" and type(C.TitleOrder) == "table", "Config.TitleDefs / TitleOrder exist")
	local seen, dup = {}, false
	for _, id in C.TitleOrder do
		if seen[id] then dup = true end
		seen[id] = true
		check(C.TitleDefs[id] ~= nil, "every TitleOrder id has a TitleDefs entry", id)
	end
	check(not dup, "TitleOrder has no duplicates", show(C.TitleOrder))
	for id, def in C.TitleDefs do
		check(seen[id] == true, "every TitleDefs id is in TitleOrder (picker)", id)
		check(type(def.Name) == "string" and def.Name ~= "" and type(def.NameEn) == "string" and def.NameEn ~= "" and def.Color ~= nil,
			"TitleDefs entry has Name / NameEn / Color", id)
		check(#id <= 32, "title ids fit the 32-char SetTitle limit", id)
	end
	check(C.TitleDefs.BetaPioneer and has(C.TitleDefs.BetaPioneer.Name, "Beta Pioneer") and has(C.TitleDefs.BetaPioneer.NameEn, "Beta Pioneer"),
		"BetaPioneer = Beta Pioneer (Name and NameEn, A23-48)", show(C.TitleDefs.BetaPioneer))
	check(C.TitleDefs.GrayLegend and C.TitleDefs.GrayLegend.Name == C.Story.GrayLegendTitle,
		"GrayLegend name = Config.Story.GrayLegendTitle (Gray Legend)", show(C.TitleDefs.GrayLegend))
	check(C.Beta.GrantPioneer == true, "Config.Beta.GrantPioneer = true")
	check(C.Beta.PioneerUntil == 1797645600 and utcStamp(2026, 12, 19, 2) == C.Beta.PioneerUntil,
		"PioneerUntil = 1797645600 = 2026-12-19 11:00 KST (02:00 UTC)", show({ C.Beta.PioneerUntil, utcStamp(2026, 12, 19, 2) }))
	check(C.RateLimits.SetTitle == 0.5, "RateLimits.SetTitle = 0.5", C.RateLimits.SetTitle)
	local D = C.Data.Defaults
	check(type(D.Titles) == "table" and next(D.Titles) == nil, "Data.Defaults.Titles = {}", show(D.Titles))
	check(D.TitleSel == "", "Data.Defaults.TitleSel = \"\"", show(D.TitleSel))
	check(D.BetaPioneer == false, "legacy Data.Defaults.BetaPioneer kept as false (migrated by TitleService)", show(D.BetaPioneer))
	check(C.Data.Version == 4, "Data.Version 4 (A23-69 stat points; the title fields were additive)", C.Data.Version)
	local mirrored = {}
	for _, k in C.Data.Mirrored do mirrored[k] = true end
	check(mirrored.TitleSel == true, "TitleSel is mirrored (attribute for nametag / HUD)")
	check(not mirrored.BetaPioneer and not mirrored.Titles and not mirrored.TitlesOwned,
		"BetaPioneer / Titles / TitlesOwned are not mirrored", show({ mirrored.BetaPioneer, mirrored.Titles, mirrored.TitlesOwned }))
end)

------------------------------------------------------------------ C2. Config.DisplayTitle order
runGroup("display-title", function()
	local DT = C.DisplayTitle
	local pioneer = C.TitleDefs.BetaPioneer.Name
	local gray = C.Story.GrayLegendTitle
	check(DT("Halo", 60, 0, 3, 3, "괴수", "BetaPioneer") == "괴수", "session title beats a selected title")
	check(DT("Halo", 60, 0, 3, 3, "", "BetaPioneer") == pioneer, "selected title beats gray legend")
	check(DT("Halo", 60, 0, 3, 3, nil, "BetaPioneer") == pioneer, "no session title (nil): selected")
	check(DT("Halo", 60, 0, 3, 3, "", "") == gray, "\"\" selected = automatic: gray legend")
	check(DT("Halo", 60, 0, 3, 3, "", "Dragon") == gray, "unknown selected id falls through to gray legend")
	check(DT("Halo", 60, 0, 2, 3, "", "Dragon") == C.GetTitle("Halo", 60, 0), "unknown selected id falls through to the rank",
		DT("Halo", 60, 0, 2, 3, "", "Dragon"))
	check(DT("Halo", 60, 0, 2, 3, "", 5) == C.GetTitle("Halo", 60, 0), "non-string selected falls through")
	check(DT("Horns", 0, 250, 0, 0, "", "GrayLegend") == C.TitleDefs.GrayLegend.Name, "selected GrayLegend shows without marks")
	check(DT("Horns", 0, 60, 0, 0) == C.GetTitle("Horns", 0, 60) and DT("Horns", 0, 60, 0, 0) == "Warlord",
		"old 5-argument call = faction rank (Warlord at 60 infamy)", DT("Horns", 0, 60, 0, 0))
	check(DT("Halo", 0, 0, 3, 3, 7, nil) == gray, "non-string session title is ignored")
	check(DT("None", 0, 0, 0, 0, "", "") == C.Titles.None, "no faction: Adventurer")
end)

------------------------------------------------------------------ C3. BetaPioneer grant / no auto-select / old auto-select reset
runGroup("title-pioneer", function()
	local uid = 9201
	local w = newWorld({ Time = UNTIL - 1 })
	local p, data = w:Join(uid)
	check(data.Titles.BetaPioneer == UNTIL - 1, "joined before PioneerUntil: Titles.BetaPioneer = os.time()", show(data.Titles))
	check(p:GetAttribute("TitlesOwned") == "BetaPioneer", "TitlesOwned = \"BetaPioneer\"", p:GetAttribute("TitlesOwned"))
	-- review of 381f6a1: no auto-select; the faction rank stays the title, the pioneer is a mark on the nametag line 2
	check(data.TitleSel == "" and p:GetAttribute("TitleSel") == "",
		"first grant keeps TitleSel \"\" (rank stays the title)", show({ data.TitleSel, p:GetAttribute("TitleSel") }))
	check(w:TitleCalls(p) == 0, "no TitleSel SetStat on the first grant", w:TitleCalls(p))
	-- the player picks the pioneer title, then switches back to automatic, then rejoins later (still in the beta)
	w.Clock += 5
	w:SetTitle(p, "BetaPioneer")
	check(data.TitleSel == "BetaPioneer" and type(data.TitleSelAt) == "number", "SetTitle(BetaPioneer) is an explicit pick (TitleSelAt)",
		show({ data.TitleSel, data.TitleSelAt }))
	w.Clock += 5
	w:SetTitle(p, "")
	check(data.TitleSel == "" and p:GetAttribute("TitleSel") == "", "SetTitle(\"\") = automatic", show(data.TitleSel))
	w:Leave(p)
	check(w:Row(uid).TitleSel == "" and w:Row(uid).Titles.BetaPioneer == UNTIL - 1, "saved: TitleSel \"\" and the owned title",
		show({ w:Row(uid).TitleSel, w:Row(uid).Titles }))
	local w2 = newWorld({ Rows = w.Rows, Time = UNTIL - 1 + 3600 })
	local p2, d2 = w2:Join(uid)
	check(d2.TitleSel == "" and p2:GetAttribute("TitleSel") == "", "a player who chose \"\" keeps \"\" on the next join",
		show({ d2.TitleSel, p2:GetAttribute("TitleSel") }))
	check(d2.Titles.BetaPioneer == UNTIL - 1 and w2:TitleCalls(p2) == 0, "not granted again (first-owned time kept, no SetStat)",
		show({ d2.Titles.BetaPioneer, w2:TitleCalls(p2) }))
	w2:Leave(p2)
	-- after the launch the owned title stays and can still be picked
	local w3 = newWorld({ Rows = w.Rows, Time = UNTIL + 86400 })
	local p3, d3 = w3:Join(uid)
	check(p3:GetAttribute("TitlesOwned") == "BetaPioneer" and d3.TitleSel == "", "after PioneerUntil the owned title stays",
		show({ p3:GetAttribute("TitlesOwned"), d3.TitleSel }))
	w3:SetTitle(p3, "BetaPioneer")
	check(d3.TitleSel == "BetaPioneer", "an owned pioneer title can still be selected after the launch", d3.TitleSel)

	-- exactly at / after PioneerUntil: no new grant
	for _, case in { { UNTIL, "exactly at PioneerUntil", 9211 }, { UNTIL + 86400, "after PioneerUntil", 9212 } } do
		local wx = newWorld({ Time = case[1] })
		local px, dx = wx:Join(case[3])
		check(next(dx.Titles) == nil and px:GetAttribute("TitlesOwned") == "" and dx.TitleSel == "",
			"fresh player " .. case[2] .. ": no title", show({ dx.Titles, px:GetAttribute("TitlesOwned"), dx.TitleSel }))
	end
	-- legacy A23-18 boolean: granted even after PioneerUntil (TitleSel stays "": no auto-select)
	local wl = newWorld({ Time = UNTIL + 86400 })
	wl.Rows[wl:Key(9220)] = row({ BetaPioneer = true })
	local pl, dl = wl:Join(9220)
	check(dl.Titles.BetaPioneer ~= nil and pl:GetAttribute("TitlesOwned") == "BetaPioneer",
		"legacy data.BetaPioneer == true migrates even after PioneerUntil", show(dl.Titles))
	check(dl.TitleSel == "", "legacy migration keeps TitleSel \"\" (no auto-select)", dl.TitleSel)
	-- GrantPioneer = false: no new grants; owned titles stay
	local off = function(config) config.Beta.GrantPioneer = false end
	local wo = newWorld({ Time = UNTIL - 86400, EditConfig = off })
	wo.Rows[wo:Key(9231)] = row({ Titles = { BetaPioneer = 1790000000 }, TitleSel = "BetaPioneer", TitleSelAt = 1790000100 })
	local fresh, df = wo:Join(9230)
	check(next(df.Titles) == nil and df.TitleSel == "", "GrantPioneer = false: no new grant before PioneerUntil", show(df.Titles))
	local owner, dw = wo:Join(9231)
	check(dw.Titles.BetaPioneer == 1790000000 and dw.TitleSel == "BetaPioneer" and owner:GetAttribute("TitlesOwned") == "BetaPioneer",
		"GrantPioneer = false: an owned pioneer title (and its selection) stays", show({ dw.Titles, dw.TitleSel }))
	wo.Rows[wo:Key(9232)] = row({ BetaPioneer = true })
	local _, dlo = wo:Join(9232)
	check(dlo.Titles.BetaPioneer ~= nil, "GrantPioneer = false: the legacy boolean still migrates (it is an owned title)",
		show(dlo.Titles))
	check(fresh:GetAttribute("TitlesOwned") == "", "GrantPioneer = false: TitlesOwned \"\"", fresh:GetAttribute("TitlesOwned"))
	-- a newly granted pioneer title never replaces another selected title
	local wg = newWorld({ Time = UNTIL - 86400 })
	wg.Rows[wg:Key(9240)] = row({ Titles = { GrayLegend = 1780000000 }, TitleSel = "GrayLegend" })
	local pg, dg = wg:Join(9240)
	check(dg.Titles.BetaPioneer ~= nil and dg.TitleSel == "GrayLegend" and pg:GetAttribute("TitleSel") == "GrayLegend",
		"new pioneer grant keeps a selected GrayLegend", show({ dg.Titles, dg.TitleSel }))
	check(wg:TitleCalls(pg) == 0, "no TitleSel SetStat for that player", wg:TitleCalls(pg))
	-- the first build auto-selected BetaPioneer (no TitleSelAt): reset to "" once; an explicit pick is kept
	local wm = newWorld({ Time = UNTIL - 86400 })
	wm.Rows[wm:Key(9250)] = row({ Titles = { BetaPioneer = 1790000000 }, TitleSel = "BetaPioneer" })
	wm.Rows[wm:Key(9251)] = row({ Titles = { BetaPioneer = 1790000000 }, TitleSel = "BetaPioneer", TitleSelAt = 1790000200 })
	local pm, dm = wm:Join(9250)
	local pk, dk = wm:Join(9251)
	check(dm.TitleSel == "" and pm:GetAttribute("TitleSel") == "" and pm:GetAttribute("TitlesOwned") == "BetaPioneer",
		"old auto-selected BetaPioneer (no TitleSelAt) goes back to automatic once; still owned", show({ dm.TitleSel, dm.Titles }))
	check(dk.TitleSel == "BetaPioneer" and pk:GetAttribute("TitleSel") == "BetaPioneer",
		"an explicitly picked BetaPioneer (TitleSelAt) is kept", show({ dk.TitleSel, dk.TitleSelAt }))
end)

------------------------------------------------------------------ C4. selected title the player does not own -> "" at ready
runGroup("title-ready-fallback", function()
	local w = newWorld({ Time = UNTIL + 86400 })
	local cases = {
		{ 9301, { TitleSel = "GrayLegend" }, "", "known but unowned GrayLegend" },
		{ 9302, { TitleSel = "Dragon" }, "", "unknown id" },
		{ 9303, { TitleSel = "BetaPioneer", Titles = {} }, "", "BetaPioneer selected but not owned" },
		{ 9304, { TitleSel = "Dragon", Titles = { Dragon = 5, BetaPioneer = 7 } }, "", "owned in data but unknown to Config" },
		{ 9305, { TitleSel = "GrayLegend", Titles = { GrayLegend = 9 } }, "GrayLegend", "owned GrayLegend kept" },
		{ 9306, { TitleSel = "BetaPioneer", Titles = { BetaPioneer = 9 }, TitleSelAt = 10 }, "BetaPioneer", "owned BetaPioneer kept" },
	}
	for _, c in cases do
		w.Rows[w:Key(c[1])] = row(c[2])
		local p, d = w:Join(c[1])
		check(d.TitleSel == c[3] and p:GetAttribute("TitleSel") == c[3], "ready: " .. c[4] .. " -> " .. (c[3] == "" and "\"\"" or c[3]),
			show({ d.TitleSel, p:GetAttribute("TitleSel") }))
	end
	local p4 = w.PlayerList[4]
	check(p4:GetAttribute("TitlesOwned") == "BetaPioneer", "TitlesOwned lists only Config.TitleDefs ids", p4:GetAttribute("TitlesOwned"))
	-- a corrupted non-string TitleSel is reset by DataService (type check) before TitleService sees it
	local wc = newWorld({ Time = UNTIL + 86400 })
	wc.AllowWarn = "field TitleSel had type number"
	wc.Rows[wc:Key(9310)] = row({ TitleSel = 7 })
	local pc, dc = wc:Join(9310)
	check(dc.TitleSel == "" and pc:GetAttribute("TitleSel") == "", "non-string saved TitleSel -> \"\"", show(dc.TitleSel))
	-- legacy record without the BB16 fields gets the defaults
	local wd = newWorld({ Time = UNTIL + 86400 })
	wd.Rows[wd:Key(9311)] = row()
	local pd, dd = wd:Join(9311)
	check(type(dd.Titles) == "table" and dd.TitleSel == "" and pd:GetAttribute("TitleSel") == "" and pd:GetAttribute("TitlesOwned") == "",
		"an old record without Titles / TitleSel gets {} / \"\"", show({ dd.Titles, dd.TitleSel }))
end)

------------------------------------------------------------------ C5. gray legend + TitlesOwned order
runGroup("title-gray-legend", function()
	local min = C.Rebirth.GrayLegendMin
	check(min == 3, "Config.Rebirth.GrayLegendMin = 3", min)
	local w = newWorld({ Time = UNTIL + 86400 })
	w.Rows[w:Key(9401)] = row({ FallMarks = min, RedeemMarks = min })
	local a, da = w:Join(9401)
	check(da.Titles.GrayLegend ~= nil and a:GetAttribute("TitlesOwned") == "GrayLegend", "both marks >= 3 at ready: GrayLegend granted",
		show(da.Titles))
	check(da.TitleSel == "", "GrayLegend is never auto-selected", da.TitleSel)
	w.Rows[w:Key(9402)] = row({ FallMarks = min, RedeemMarks = min - 1 })
	local b, db = w:Join(9402)
	check(db.Titles.GrayLegend == nil and b:GetAttribute("TitlesOwned") == "", "3 / 2 marks: no GrayLegend", show(db.Titles))
	w.PS.SetStat(b, "RedeemMarks", min)
	check(db.Titles.GrayLegend ~= nil and b:GetAttribute("TitlesOwned") == "GrayLegend", "RedeemMarks reaching 3 later grants it at once",
		show(db.Titles))
	w.Rows[w:Key(9403)] = row({ FallMarks = min - 1, RedeemMarks = min })
	local c, dc = w:Join(9403)
	check(dc.Titles.GrayLegend == nil, "2 / 3 marks: none yet")
	w.PS.SetStat(c, "FallMarks", min)
	check(dc.Titles.GrayLegend ~= nil and c:GetAttribute("TitlesOwned") == "GrayLegend", "FallMarks reaching 3 later grants it at once",
		show(dc.Titles))
	w.Rows[w:Key(9404)] = row({ FallMarks = 5, RedeemMarks = 1 })
	local e, de = w:Join(9404)
	w.PS.SetStat(e, "FallMarks", 4)
	check(de.Titles.GrayLegend == nil, "one mark alone (5 / 1 -> 4 / 1) never grants it", show(de.Titles))
	-- kept once earned
	w.PS.SetStat(c, "FallMarks", 0)
	check(dc.Titles.GrayLegend ~= nil and c:GetAttribute("TitlesOwned") == "GrayLegend", "GrayLegend stays when the marks drop")
	-- TitlesOwned follows TitleOrder and skips unknown ids
	local wo = newWorld({ Time = UNTIL - 86400 })
	wo.Rows[wo:Key(9410)] = row({ Titles = { GrayLegend = 5, Dragon = 6, Zebra = 7 } })
	local o = wo:Join(9410)
	check(o:GetAttribute("TitlesOwned") == "BetaPioneer,GrayLegend", "TitlesOwned = owned ids in Config.TitleOrder, joined by \",\"",
		o:GetAttribute("TitlesOwned"))
	local wp = newWorld({ Time = UNTIL - 86400 })
	wp.Rows[wp:Key(9411)] = row({ FallMarks = min, RedeemMarks = min })
	local q = wp:Join(9411)
	check(q:GetAttribute("TitlesOwned") == "BetaPioneer,GrayLegend", "pioneer + gray legend in TitleOrder order",
		q:GetAttribute("TitlesOwned"))
end)

------------------------------------------------------------------ C6. SetTitle remote
runGroup("title-set-remote", function()
	local L32, L33 = string.rep("L", 32), string.rep("M", 33)
	local edit = function(config)
		config.TitleDefs[L32] = { Name = "32", NameEn = "32", Color = vec(1, 1, 1) }
		config.TitleDefs[L33] = { Name = "33", NameEn = "33", Color = vec(1, 1, 1) }
	end
	local w = newWorld({ Time = UNTIL + 86400, EditConfig = edit })
	w.Rows[w:Key(9501)] = row({ Titles = { BetaPioneer = 1, GrayLegend = 2, [L32] = 3, [L33] = 4 }, TitleSel = "BetaPioneer" })
	w.Rows[w:Key(9502)] = row({ Titles = { BetaPioneer = 1 } })
	local p, d = w:Join(9501)
	local other, dOther = w:Join(9502)
	w:Flush()
	local function sel() return d.TitleSel end
	local function accepted(label, ...)
		w.Clock += 1
		w:SetTitle(p, ...)
		local want = ...
		check(d.TitleSel == want and p:GetAttribute("TitleSel") == want, "accepted: " .. label, show({ d.TitleSel, p:GetAttribute("TitleSel") }))
	end
	local function ignored(label, target, ...)
		w.Clock += 1
		local who, data = target or p, (target and dOther) or d
		local before, attr, calls = data.TitleSel, who:GetAttribute("TitleSel"), w:TitleCalls(who)
		w:SetTitle(who, ...)
		check(data.TitleSel == before and who:GetAttribute("TitleSel") == attr and w:TitleCalls(who) == calls, "ignored: " .. label,
			show({ before, data.TitleSel }))
	end
	-- "Titles never give stats": everything below may write TitleSel only
	local mark = #p.Log
	local cp, pow = p:GetAttribute("CombatPower"), w.Justice.GetPower(p)
	accepted("owned GrayLegend", "GrayLegend")
	accepted("\"\" (automatic)", "")
	accepted("owned BetaPioneer", "BetaPioneer")
	accepted("owned id of exactly 32 chars", L32)
	accepted("back to GrayLegend", "GrayLegend")
	ignored("no argument")
	ignored("two arguments", nil, "BetaPioneer", "x")
	ignored("two arguments (second nil)", nil, "BetaPioneer", nil)
	ignored("number", nil, 5)
	ignored("boolean", nil, true)
	ignored("table", nil, { "BetaPioneer" })
	ignored("nil", nil, nil)
	ignored("owned id of 33 chars (too long)", nil, L33)
	ignored("unknown id", nil, "Dragon")
	ignored("known but unowned id (GrayLegend for the other player)", other, "GrayLegend")
	check(dOther.TitleSel == "BetaPioneer" or dOther.TitleSel == "", "other player unchanged by the refused call", dOther.TitleSel)
	w.Ready[p] = nil
	ignored("player not ready", nil, "BetaPioneer")
	w.Ready[p] = true
	-- rate limit: RateLimits.SetTitle = 0.5 s between ACCEPTED calls
	w.Clock += 1
	w:SetTitle(p, "BetaPioneer")
	check(sel() == "BetaPioneer", "accepted after a pause", sel())
	w.Clock += 0.25
	w:SetTitle(p, "")
	check(sel() == "BetaPioneer", "ignored: a second call 0.25 s later (inside RateLimits.SetTitle)", sel())
	w.Clock += 0.25
	w:SetTitle(p, "")
	check(sel() == "", "accepted 0.5 s after the last accepted call", sel())
	-- no stats: only TitleSel was written on this player, power unchanged
	local others = {}
	for i = mark + 1, #p.Log do
		if p.Log[i].Key ~= "TitleSel" then table.insert(others, p.Log[i].Key) end
	end
	check(#others == 0, "SetTitle writes only the TitleSel attribute", table.concat(others, ","))
	check(p:GetAttribute("CombatPower") == cp and w.Justice.GetPower(p) == pow, "title changes never change CombatPower / power")
	-- the choice is saved
	w:Leave(p)
	check(w:Row(9501).TitleSel == "", "the last accepted choice is saved", w:Row(9501).TitleSel)
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
print("BETA_BASICS_RESULT_JSON " .. enc({ Checks = total, Failed = failedCount, Named = list, Findings = findings }))
if failedCount == 0 then
	print("BETA_BASICS_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
else
	print("BETA_BASICS_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
end
