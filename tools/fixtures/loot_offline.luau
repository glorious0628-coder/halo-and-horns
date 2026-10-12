-- A23-11 / A23-12 loot, items and scroll enhancement (+ the A23-15 announcements LootService asks for), run offline.
-- tools/test_loot.py injects the CURRENT repository sources before this file (CONFIG_SOURCE, NET_SOURCE, UTIL_SOURCE,
-- DATA_SOURCE, SET_STAT_SOURCE = PlayerService.SetStat/AddStat, GOLD_SOURCE = ProgressionService, COMBAT_SOURCE,
-- LOOT_SOURCE, the extracted power helpers JUSTICE_POWER_SOURCE / PVP_POWER_SOURCE and SHOP_BUY_SOURCE = ShopService's
-- onUpgradeWeapon + finite + notifyBad) plus SAMPLE_SCALE. Only engine /
-- service boundaries are doubles: no Studio, no network, no DataStore. AnnounceService is a recording stub
-- (f.Announces = { Player, Key, Args, Grade, Extra }); the real chat grouping / client text is not exercised here.
-- Every check is named and collected (a failure never aborts the run); the result is one JSON line at the end.

------------------------------------------------------------------ check collection
local results, order, stats, findings = {}, {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
local groupFixtures = {}

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

------------------------------------------------------------------ small helpers
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[deepCopy(k)] = deepCopy(x) end
	return out
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b or (a ~= a and b ~= b) end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function show(v)
	if type(v) ~= "table" then return tostring(v) end
	local parts = {}
	for k, x in v do table.insert(parts, tostring(k) .. "=" .. show(x)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

-- binomial tolerance: |hits - n p| <= z sd + 1 (seeded, so deterministic; z = 5 keeps it free of flukes)
local function within(hits, n, p)
	if n <= 0 then return false end
	return math.abs(hits - n * p) <= 5 * math.sqrt(n * p * (1 - p)) + 1
end

local function stat(key, hits, n, p)
	stats[key] = { N = n, Hits = hits, Expected = p, Rate = n > 0 and hits / n or 0 }
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

------------------------------------------------------------------ JSON (Roblox HttpService / DataStore stand-in)
local JSON = {}
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

function JSON.encode(v)
	local t = type(v)
	if v == nil then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then error("JSONEncode: NaN/inf is not valid JSON") end
		if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
		return string.format("%.17g", v)
	end
	if t == "string" then
		return '"' .. (string.gsub(v, '[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", string.byte(c)) end)) .. '"'
	end
	if t == "table" then
		local n, numeric, strings = 0, 0, 0
		for k in v do
			n += 1
			if type(k) == "number" then numeric += 1
			elseif type(k) == "string" then strings += 1
			else error("JSONEncode: key of type " .. type(k)) end
		end
		if n == 0 then return "[]" end
		if numeric == n then
			local parts = {}
			for i = 1, n do
				if v[i] == nil then error("JSONEncode: sparse array") end
				parts[i] = JSON.encode(v[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		if strings ~= n then error("JSONEncode: mixed table keys") end
		local keys = {}
		for k in v do table.insert(keys, k) end
		table.sort(keys)
		local parts = {}
		for _, k in keys do table.insert(parts, JSON.encode(k) .. ":" .. JSON.encode(v[k])) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("JSONEncode: cannot encode " .. t)
end

function JSON.decode(s)
	assert(type(s) == "string", "JSONDecode: not a string")
	local pos = 1
	local function ws() pos = string.find(s, "[^ \t\r\n]", pos) or (#s + 1) end
	local value
	local function str()
		pos += 1
		local out = {}
		while true do
			local c = string.sub(s, pos, pos)
			if c == "" then error("JSONDecode: unterminated string") end
			if c == '"' then pos += 1; break end
			if c == "\\" then
				local e = string.sub(s, pos + 1, pos + 1)
				if e == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(s, pos + 2, pos + 5), 16)))
					pos += 6
				else
					local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
					table.insert(out, (assert(map[e], "JSONDecode: bad escape")))
					pos += 2
				end
			else
				table.insert(out, c)
				pos += 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = string.sub(s, pos, pos)
		if c == "{" then
			pos += 1
			local obj = {}
			ws()
			if string.sub(s, pos, pos) == "}" then pos += 1; return obj end
			while true do
				ws()
				assert(string.sub(s, pos, pos) == '"', "JSONDecode: object key expected")
				local k = str()
				ws()
				assert(string.sub(s, pos, pos) == ":", "JSONDecode: ':' expected")
				pos += 1
				obj[k] = value()
				ws()
				local d = string.sub(s, pos, pos)
				pos += 1
				if d == "}" then return obj end
				assert(d == ",", "JSONDecode: ',' expected")
			end
		elseif c == "[" then
			pos += 1
			local arr = {}
			ws()
			if string.sub(s, pos, pos) == "]" then pos += 1; return arr end
			while true do
				table.insert(arr, value())
				ws()
				local d = string.sub(s, pos, pos)
				pos += 1
				if d == "]" then return arr end
				assert(d == ",", "JSONDecode: ',' expected")
			end
		elseif c == '"' then
			return str()
		elseif string.sub(s, pos, pos + 3) == "true" then pos += 4; return true
		elseif string.sub(s, pos, pos + 4) == "false" then pos += 5; return false
		elseif string.sub(s, pos, pos + 3) == "null" then pos += 4; return nil
		end
		local num = string.match(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		assert(num and num ~= "", "JSONDecode: unexpected character at " .. pos)
		pos += #num
		return (assert(tonumber(num), "JSONDecode: bad number"))
	end
	local result = value()
	ws()
	assert(pos > #s, "JSONDecode: trailing characters")
	return result
end

------------------------------------------------------------------ engine doubles
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
	if key == "Unit" then local n = v.Magnitude; return vec(v.X / n, v.Y / n, v.Z / n) end
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
		CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum }
end

local function typeofDouble(v) return type(v) == "table" and v.__kind or type(v) end

local ATTRIBUTE_TYPES = { ["nil"] = true, string = true, number = true, boolean = true }
-- a living character for Util.IsAlive / GetRoot (review B6: equip needs a live character); f.Dead = true kills it
local function newCharacter(f)
	local root = { __kind = "Instance", ClassName = "Part", Name = "HumanoidRootPart", Position = vec(0, 0, 0) }
	function root:IsA(kind) return kind == "BasePart" or kind == "Part" end
	local humanoid = setmetatable({ __kind = "Instance", ClassName = "Humanoid", MaxHealth = 100 }, {
		__index = function(_, key) if key == "Health" then return f.Dead == true and 0 or 100 end end })
	function humanoid:IsA(kind) return kind == "Humanoid" end
	local c = { __kind = "Instance", ClassName = "Model", Name = "Character", Parent = {} }
	function c:FindFirstChildOfClass(kind) if kind == "Humanoid" then return humanoid end end
	function c:FindFirstChild(name)
		if name == "HumanoidRootPart" then return root elseif name == "Humanoid" then return humanoid end
	end
	function c:IsA(kind) return kind == "Model" end
	return c
end

local function newPlayer(f, userId, playersService)
	local p = { __kind = "Instance", ClassName = "Player", UserId = userId, Name = "Tester" .. userId,
		DisplayName = "Tester" .. userId, Parent = playersService, Attrs = {}, Sig = {} }
	p.Character = newCharacter(f)
	function p:IsA(kind) return kind == "Player" end
	function p:GetAttribute(key) return self.Attrs[key] end
	function p:SetAttribute(key, value)
		if not ATTRIBUTE_TYPES[type(value)] then error("SetAttribute: unsupported attribute type " .. type(value) .. " for " .. key) end
		local old = self.Attrs[key]
		self.Attrs[key] = value
		if old ~= value and self.Sig[key] then self.Sig[key]:Fire() end
	end
	function p:GetAttributeChangedSignal(key)
		if not self.Sig[key] then self.Sig[key] = signal() end
		return self.Sig[key]
	end
	table.insert(f.PlayerList, p)
	return p
end

-- world(f): Roblox services + a per-module env factory shared by the loot and combat fixtures
local guidSerial = 0
local function world(f, config, rows)
	local players = { __kind = "Instance", Name = "Players" }
	function players:GetPlayers() return f.PlayerList end
	local shared = { Config = "Config", Util = "Util", Net = "Net" }
	function shared:WaitForChild(name) return assert(rawget(self, name), "missing Shared." .. tostring(name)) end
	local replicated = { Shared = shared }
	function replicated:WaitForChild(name) return assert(rawget(self, name), "missing " .. tostring(name)) end
	local db = {}
	function db:GetAsync(key) return deepCopy(rows[key]) end
	function db:UpdateAsync(key, fn)
		local result = fn(deepCopy(rows[key]))
		-- what a DataStore really keeps: the JSON round trip of the returned value
		if result ~= nil then rows[key] = JSON.decode(JSON.encode(result)) end
		return deepCopy(rows[key])
	end
	local services = {
		Players = players, ReplicatedStorage = replicated,
		HttpService = {
			JSONEncode = function(_, v) return JSON.encode(v) end,
			JSONDecode = function(_, s) return JSON.decode(s) end,
			GenerateGUID = function() guidSerial += 1; return "guid-" .. guidSerial end,
		},
		RunService = { IsStudio = function() return true end, IsServer = function() return true end, IsClient = function() return false end },
		DataStoreService = { GetDataStore = function() return db end },
	}
	local game = { JobId = "offline-loot", GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	local ws = { GetServerTimeNow = function() return f.Now end }
	local osDouble = { clock = function() return f.Now end, time = function() return math.floor(f.Time) end, date = os.date }
	local plainRandom = { new = function()
		local r = {}
		function r:NextNumber(a, b) local v = math.random(); if a ~= nil then return a + (b - a) * v end; return v end
		function r:NextInteger(a, b) return math.random(a, b) end
		return r
	end }
	local modules = {}
	local function env(extra)
		local e = { game = game, workspace = ws, typeof = typeofDouble, Vector3 = { new = vec, zero = vec(0, 0, 0) },
			Vector2 = { new = vec }, os = osDouble, Random = plainRandom, print = function() end,
			warn = function(...) table.insert(f.Warnings, table.concat({ ... }, " ")) end,
			task = { spawn = function(fn) table.insert(f.Tasks, fn) end, wait = function() error("unexpected yield") end,
				delay = function(_, fn) table.insert(f.Tasks, fn) end,
				-- task.defer runs at the end of the frame: queued here and run by f:Flush() (LootService Inventory push)
				defer = function(fn, ...) table.insert(f.Deferred, table.pack(fn, ...)) end },
			require = function(name) return assert(modules[name], "unexpected require " .. tostring(name)) end }
		for k, v in extra or {} do e[k] = v end
		return e
	end
	modules.Config = config
	return { Players = players, Env = env, Modules = modules, Services = services }
end

------------------------------------------------------------------ loot fixture
local DEFAULT_ROW = { Version = 2, ClassChosen = true, Class = "Warrior", Faction = "Halo", Level = 1, WeaponTier = 1,
	WeaponOwnedMask = 1, TutorialStep = 99 }
local serial = 5000

-- opts: Fresh (no stored row), Saved (stored row), Rows (shared store rows for save/reload), UserId
local function fixture(opts)
	opts = opts or {}
	serial += 1
	local f = { Now = 1000, Time = 1.8e9, Ready = true, ReadySet = {}, NearAnvil = true, InCombat = false, Draws = 0,
		Script = {}, ScriptConst = nil, Notices = {}, All = {}, FxLog = {}, Warnings = {}, GoldLog = {}, Active = 0,
		Tasks = {}, PlayerList = {}, EnhLog = {}, Deferred = {}, Inventory = {}, Leaks = {}, Dead = false, Announces = {} }
	table.insert(groupFixtures, f)
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	local L = config.Loot
	f.Config, f.L = config, L
	local rows = opts.Rows or {}
	f.Rows = rows
	f.UserId = opts.UserId or serial
	if not opts.Fresh and rows["P_" .. f.UserId] == nil then rows["P_" .. f.UserId] = deepCopy(opts.Saved or DEFAULT_ROW) end
	local w = world(f, config, rows)
	f.World = w
	local util = execute("Util", UTIL_SOURCE, w.Env())
	w.Modules.Util = util
	local remotes = {}
	local net = {}
	function net.Get(name)
		if not remotes[name] then
			remotes[name] = { OnServerEvent = signal(),
				-- review B11: the owner-only "Inventory" remote; anything else fired to clients is a leak
				FireClient = function(_, player, payload, ...)
					if name == "Inventory" then
						table.insert(f.Inventory, { Player = player, Payload = deepCopy(payload), Extra = select("#", ...) })
					else
						table.insert(f.Leaks, "FireClient " .. name)
					end
				end,
				FireAllClients = function() table.insert(f.Leaks, "FireAllClients " .. name) end,
			}
		end
		return remotes[name]
	end
	function net.Notify(player, text, kind, duration)
		table.insert(f.Notices, { Player = player, Text = text, Kind = kind, Duration = duration })
	end
	function net.NotifyAll(text, kind, duration)
		table.insert(f.All, { Text = text, Kind = kind, Duration = duration })
		if f.OnNotifyAll then f.OnNotifyAll(text, kind) end
	end
	function net.Fx(player, kind, data) table.insert(f.FxLog, { Player = player, Kind = kind, Data = data }) end
	w.Modules.Net = net
	f.Remotes = remotes

	local ds = execute("DataService", DATA_SOURCE, w.Env())
	ds.Init({})
	ds.Start()
	f.Tasks[1]() -- the DataStore probe; the autosave loop stays unstarted
	f.Tasks = {}

	local ps = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterDied = signal(), CharacterSpawned = signal() }
	ps.IsReady = function(p) return f.Ready == true and f.ReadySet[p] == true end
	ps.GetData = function(p) return ds.Get(p) end
	ps.GetReadyPlayers = function()
		local out = {}
		for _, p in f.PlayerList do if f.ReadySet[p] then table.insert(out, p) end end
		return out
	end
	ps.MarkActive = function() f.Active += 1 end
	ps.Respawn = function() f.Respawned = (f.Respawned or 0) + 1 end
	ps.RefreshCharacter = function() end
	ps.IsShuttingDown = function() return false end
	local mirrored = {}
	for _, key in config.Data.Mirrored do mirrored[key] = true end
	local setStat = execute("PlayerService.SetStat", SET_STAT_SOURCE, w.Env(), { DataService = ds }, mirrored)
	ps.SetStat, ps.AddStat = setStat.SetStat, setStat.AddStat

	local registry = {
		PlayerService = ps, DataService = ds,
		MonsterService = { MonsterKilled = signal() },
		ClassService = { GetClass = function(p) return p:GetAttribute("Class") or "Warrior" end, ClassChanged = signal(),
			GetClassDef = function(p) return config.Classes[p:GetAttribute("Class") or "Warrior"] end },
		CombatService = { IsInCombat = function() return f.InCombat == true end },
		ShopService = { CanBuyWeapon = function() f.AnvilAsked = (f.AnvilAsked or 0) + 1; return f.NearAnvil == true end },
		FactionService = { FactionChanged = signal(),
			GetFaction = function(p) return p:GetAttribute("Faction") or "None" end,
			GetPerks = function(p) return config.Factions[p:GetAttribute("Faction") or "None"] or config.Factions.None end,
			GetUnderdogCounts = function() return 3, 3 end, GetCounts = function() return 3, 3 end,
			SetFaction = function(p, factionId) ps.SetStat(p, "Faction", factionId) end },
		PvPService = { GetStars = function() return 0 end, IsRookie = function() return false end, HasRevenge = function() return false end },
		GrudgeService = { HasSack = function() return false end },
		KaijuService = { GetState = function() return "None" end },
		WarService = { HasBlessing = function() return false end },
		JusticeService = { GetBullyStacks = function() return 0 end, GetDamageMult = function() return 1 end },
		-- A23-15: LootService.announce -> AnnounceService.Announce(player, key, args, gradeId). Recorded (args copied at the
		-- call), then f.OnAnnounce(player, key, args, grade) runs; f.AnnounceThrows = true makes the stub raise afterwards.
		-- Tests remove it with f.Registry.AnnounceService = nil (LootService must skip silently).
		AnnounceService = { Announce = function(player, key, args, grade, ...)
			table.insert(f.Announces, { Player = player, Key = key, Args = deepCopy(args), Grade = grade, Extra = select("#", ...) })
			if f.OnAnnounce then f.OnAnnounce(player, key, args, grade) end
			if f.AnnounceThrows then error("AnnounceService stub failure") end
		end },
	}
	f.Registry, f.PS, f.DS = registry, ps, ds

	local prog = execute("ProgressionService", GOLD_SOURCE, w.Env())
	registry.ProgressionService = prog
	prog.Init(registry)
	prog.GoldEarned:Connect(function(p, amount, source) table.insert(f.GoldLog, { Player = p, Amount = amount, Source = source }) end)
	f.Prog = prog

	-- LootService gets its own Random: scripted values first, then a constant, else the seeded math.random stream
	local lootRandom = { new = function()
		local r = {}
		function r:NextNumber(a, b)
			f.Draws += 1
			local v
			if #f.Script > 0 then v = table.remove(f.Script, 1)
			elseif f.ScriptConst ~= nil then v = f.ScriptConst
			else v = math.random() end
			if a ~= nil then return a + (b - a) * v end
			return v
		end
		function r:NextInteger(a, b) f.Draws += 1; return math.random(a, b) end
		return r
	end }
	local loot = execute("LootService", LOOT_SOURCE, w.Env({ Random = lootRandom }))
	registry.LootService = loot
	loot.Init(registry)
	loot.Start()
	-- A23-28: ShopService's weapon buy / re-equip handler (onUpgradeWeapon + finite + notifyBad, extracted by the runner)
	-- with the real Config / Util / ProgressionService.SpendGold; the anvil distance check is a stub (f.NearAnvil)
	local shopBuy = execute("ShopService.onUpgradeWeapon", SHOP_BUY_SOURCE, w.Env(), config, util, net, registry)
	shopBuy.M.CanBuyWeapon = function() return f.NearAnvil == true end
	loot.Enhanced:Connect(function(p, tier, before, after, success)
		table.insert(f.EnhLog, { Player = p, Tier = tier, Before = before, After = after, Success = success })
	end)
	f.Loot = loot

	function f:Join(userId)
		local p = newPlayer(self, userId, w.Players)
		local data = ds.Load(p)
		assert(data, "DataService.Load failed for " .. userId)
		self.ReadySet[p] = true
		for key in mirrored do p:SetAttribute(key, data[key]) end
		ps.PlayerReady:Fire(p, data)
		return p, data
	end
	f.Player, f.Data = f:Join(f.UserId)

	function f:Fire(remote, ...) self.Now += 1; remotes[remote].OnServerEvent:Fire(self.Player, ...) end
	function f:FireRaw(remote, ...) remotes[remote].OnServerEvent:Fire(self.Player, ...) end
	function f:Use(...) self:Fire("UseItem", ...) end
	function f:Equip(...) self:Fire("EquipWeapon", ...) end
	function f:ShopBuy(tier) self.Now += 1; return shopBuy.Buy(self.Player, tier) end
	function f:Sell(...) self:Fire("SellMaterials", ...) end
	function f:Set(key, value) ps.SetStat(self.Player, key, value) end
	function f:Give(id, n) return loot.DebugGive(self.Player, id, n) end
	function f:Count(id) return self.Data.Items[id] or 0 end
	function f:Enh(tier) return self.Data.WeaponEnhance[tier] end
	function f:Kill(kind, extra, player)
		local info = { Kind = kind, Golden = false, Position = vec(10, 0, 10), XP = 0, Gold = 0, WarPoints = 0, WarShare = 0 }
		for k, v in extra or {} do info[k] = v end
		registry.MonsterService.MonsterKilled:Fire(player or self.Player, info)
	end
	function f:Roll(kind, golden, extra)
		local info = { Kind = kind, Golden = golden, Position = vec(10, 0, 10) }
		for k, v in extra or {} do info[k] = v end
		return loot.RollKill(self.Player, info)
	end
	-- scripted roll: only the listed row indices (and optionally the jackpot) succeed
	function f:Force(kind, hitRows, jackpot, golden, extra)
		-- a BelowLevel weapon row below its MinLevel draws nothing (A23-27): no script value, counted as left over
		local script, skipped = {}, 0
		local level = math.floor(tonumber(self.Data.Level) or 1)
		for i, row in L.Tables[kind] or {} do
			if row.Weapon and type(row.BelowLevel) == "table" and level < self.Config.Weapons[row.Weapon].MinLevel then
				skipped += 1
			else
				table.insert(script, (hitRows and hitRows[i]) and 0 or 0.999999)
			end
		end
		if L.Jackpot.Monsters[kind] then table.insert(script, jackpot and 0 or 0.999999) end
		self.Script = script
		local g = self:Roll(kind, golden, extra)
		local left = #self.Script + skipped
		self.Script = {}
		return g, left
	end
	function f:Noticed(text)
		local n = 0
		for _, e in self.Notices do if e.Text == text then n += 1 end end
		return n
	end
	-- the recorded AnnounceService calls with this key (in call order)
	function f:Announced(key)
		local out = {}
		for _, a in self.Announces do if a.Key == key then table.insert(out, a) end end
		return out
	end
	function f:State()
		local d = self.Data
		return deepCopy({ Items = d.Items, Enh = d.WeaponEnhance, Mask = d.WeaponOwnedMask, Tier = d.WeaponTier,
			Carried = d.CarriedGold, Bank = d.BankGold, Flags = d.LootFlags, HP = d.HPPotionCount, MP = d.MPPotionCount,
			Level = d.Level, AttrTier = self.Player:GetAttribute("WeaponTier"), AttrEnh = self.Player:GetAttribute("WeaponEnhance") })
	end
	function f:Release()
		ds.Release(self.Player)
		self.ReadySet[self.Player] = nil
		self.Player.Parent = nil
	end
	function f:Gained(g, key, value)
		local n = 0
		for _, e in g or {} do if e[key] == value then n += (e.N or 1) end end
		return n
	end
	-- run every queued task.defer (end of frame); returns how many ran
	function f:Flush()
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
	-- the Inventory payloads sent to `player` (default: the fixture player) since the last call, after a flush
	function f:Pushes(player)
		self:Flush()
		local out = {}
		for _, e in self.Inventory do
			if e.Player == (player or self.Player) then table.insert(out, e) end
		end
		self.Inventory = {}
		return out
	end
	function f:LastPayload(player)
		local list = self:Pushes(player)
		return list[#list] and list[#list].Payload or nil, #list
	end
	return f
end

local function rowIndex(L, kind, key, value)
	for i, row in L.Tables[kind] do if row[key] == value then return i end end
	return nil
end

-- A23-27: weapon rows with a BelowLevel table are not drawn for a killer below that weapon's MinLevel (they pay the
-- BelowLevel item instead). Counted from Config.Weapons[].MinLevel directly (not Config.WeaponUsable, which is tested).
local function belowLevelRows(f, kind, level)
	local n = 0
	for _, row in f.L.Tables[kind] or {} do
		if row.Weapon and type(row.BelowLevel) == "table" and level < f.Config.Weapons[row.Weapon].MinLevel then n += 1 end
	end
	return n
end

local function tierMask(...)
	local m = 0
	for _, t in { ... } do m = bit32.bor(m, bit32.lshift(1, t - 1)) end
	return m
end

-- A23-28 notices sent to x's player: every possible WeaponAutoSwap (any MinLevel) / WeaponUsableNow text -> the tier it names
local function weaponNotices(x, key)
	local C = x.Config
	local class, faction = x.Player:GetAttribute("Class") or "Warrior", x.Player:GetAttribute("Faction") or "None"
	local set, out = {}, {}
	for t = 1, C.MaxWeaponTier do
		local name = C.WeaponName(t, class, faction)
		if key == "WeaponAutoSwap" then
			for m = 1, C.MaxWeaponTier do set[string.format(C.Text.WeaponAutoSwap, C.Weapons[m].MinLevel, name)] = t end
		else
			set[string.format(C.Text[key], name)] = t
		end
	end
	for _, e in x.Notices do
		if set[e.Text] then table.insert(out, { Tier = set[e.Text], Kind = e.Kind, Text = e.Text }) end
	end
	return out
end

------------------------------------------------------------------ group runner
local function runGroup(name, fn)
	currentGroup = name
	groupFixtures = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	local bad = {}
	for _, f in groupFixtures do
		for _, w in f.Warnings do
			if string.find(w, "LootService", 1, true) or string.find(w, "handler error", 1, true)
				or string.find(w, "ProgressionService", 1, true) then
				table.insert(bad, w)
			end
		end
	end
	check(#bad == 0, "no LootService / ProgressionService runtime errors (pcall-swallowed handler errors)", bad[1])
	local leaks, wrongOwner = {}, 0
	for _, f in groupFixtures do
		for _, l in f.Leaks or {} do table.insert(leaks, l) end
		if f.Flush then f:Flush() end
		for _, e in f.Inventory or {} do
			if type(e.Player) ~= "table" or e.Player.ClassName ~= "Player" or e.Extra ~= 0 then wrongOwner += 1 end
		end
	end
	-- review B11: inventory data goes only to its owner (FireClient(player, payload)); never FireAllClients
	check(#leaks == 0, "no remote fired to all clients / no unexpected client publication", leaks[1])
	check(wrongOwner == 0, "every Inventory push is FireClient(player, payload) with no extra arguments", wrongOwner)
end

------------------------------------------------------------------ 0. config contract
runGroup("config", function()
	local f = fixture()
	local C, L = f.Config, f.L
	check(L.MaxEnhance == 10, "MaxEnhance is 10", L.MaxEnhance)
	check(L.EnhancePerLevel == 0.10, "EnhancePerLevel is 0.10", L.EnhancePerLevel)
	check(L.FailDropChance == 0.5, "FailDropChance is 0.5", L.FailDropChance)
	check(L.ItemCap == 999, "ItemCap is 999", L.ItemCap)
	check(L.GoldenMult == 3, "GoldenMult is 3", L.GoldenMult)
	-- C1 (save v4): tier 9 = Mythic (crafted only)
	check(C.MaxWeaponTier == 9 and #C.Weapons == 9, "MaxWeaponTier is 9", C.MaxWeaponTier)
	local w8 = C.Weapons[8]
	check(w8 and w8.Legend == true and w8.MinLevel == 1 and (w8.Price or 0) == 0 and not w8.RequiresFaction,
		"tier 8 is the legendary: Legend=true, MinLevel 1, never sold, no faction gate", show(w8 and { w8.Legend, w8.MinLevel, w8.Price }))
	-- A23-14 / review B1: 70% = +1, 30% = +3, 10% = +5 (failure 50% -1 / 50% kept, unchanged)
	for id, want in { Enh70 = { 0.7, 1 }, Enh30 = { 0.3, 3 }, Enh10 = { 0.1, 5 } } do
		local d = L.Items[id]
		check(d and d.Kind == "Enhance" and d.Chance == want[1] and d.Plus == want[2], "enhance scroll " .. id .. " chance/plus", show(d))
		-- expected change per use while the gain fits under +10 (start +1..10-Plus): Chance x Plus - (1 - Chance) x FailDrop
		if d then
			local e = d.Chance * d.Plus - (1 - d.Chance) * L.FailDropChance
			check(e >= 0, "B1: no enhance scroll loses enhancement on average (+1..+9 before the cap)", id .. " " .. e)
			local want0 = d.Chance * d.Plus
			check(math.abs(e - ({ Enh70 = 0.55, Enh30 = 0.55, Enh10 = 0.05 })[id]) < 1e-9 and want0 > 0,
				"B1 expected gain per use at +1..+9 = +0.55 / +0.55 / +0.05", id .. " " .. e)
		end
	end
	-- review B2: scroll chances rise with the zone (reviewer table), transfer scrolls about 1/3 of the same row
	local B2 = { Slime = { 0.003, 0.0008, 0.0002 }, BigSlime = { 0.03, 0.008, 0.002 }, Goblin = { 0.015, 0.004, 0.001 },
		GoblinBrute = { 0.05, 0.014, 0.0035 }, Skeleton = { 0.025, 0.007, 0.0018 }, SkeletonKnight = { 0.08, 0.022, 0.006 } }
	local function rowP(kind, key, value)
		for _, row in L.Tables[kind] or {} do if row[key] == value then return row.P end end
		return nil
	end
	for kind, want in B2 do
		for i, id in { "Enh70", "Enh30", "Enh10" } do
			check(rowP(kind, "Item", id) == want[i], "B2 scroll drop chance = reviewer table", kind .. "." .. id .. " " .. tostring(rowP(kind, "Item", id)))
			local move = rowP(kind, "Item", "Move" .. string.sub(id, 4))
			check(type(move) == "number" and move > 0 and move >= want[i] / 4 and move <= want[i] / 2,
				"B2 transfer scroll chance is about 1/3 (1/4..1/2) of the same enhance row (kept: A23-11 three kinds)", kind .. ".Move" .. string.sub(id, 4) .. " " .. tostring(move))
		end
	end
	for _, chain in { { "Slime", "Goblin", "Skeleton" }, { "BigSlime", "GoblinBrute", "SkeletonKnight" } } do
		for _, id in { "Enh70", "Enh30", "Enh10" } do
			local a, b, c = rowP(chain[1], "Item", id), rowP(chain[2], "Item", id), rowP(chain[3], "Item", id)
			check(a and b and c and a < b and b < c, "B2 scroll chance rises meadow < woods < ruins", id .. " " .. show({ a, b, c }))
		end
	end
	-- review B13: potions about half of the first values, the same for HP and MP
	local POTION = { Slime = 0.01, BigSlime = 0.03, Goblin = 0.02, GoblinBrute = 0.04, Skeleton = 0.025, SkeletonKnight = 0.05 }
	for kind, p in POTION do
		check(rowP(kind, "Potion", "HP") == p and rowP(kind, "Potion", "MP") == p, "B13 potion chances halved (HP = MP)",
			kind .. " " .. show({ rowP(kind, "Potion", "HP"), rowP(kind, "Potion", "MP") }))
	end
	-- manual meadow pace assumed by the review: 5 kills/min, 1 king slime per 8 kills -> potions per hour (finding only)
	local perKill = (7 * (rowP("Slime", "Potion", "HP") + rowP("Slime", "Potion", "MP"))
		+ (rowP("BigSlime", "Potion", "HP") + rowP("BigSlime", "Potion", "MP"))) / 8
	finding(string.format("B13 estimate: %.1f potions per manual meadow hour at 5 kills/min (assumed 1 king slime per 8 kills); "
		.. "%.1f at Config.Economy.KillsPerMinute 12. Target 8-14/h: re-measure in the 15-minute hand run.",
		perKill * 300, perKill * 720))
	check(perKill * 300 > 0 and perKill * 300 <= 14, "B13 meadow potions per manual hour (5 kills/min) at most 14", perKill * 300)
	check(L.FullNoticeSeconds == 300, "B7 FullNoticeSeconds is 300 (5 min per item id)", L.FullNoticeSeconds)
	check(L.FirstScroll.NoticeSeconds == 6, "first-scroll guide shows 6 s", L.FirstScroll.NoticeSeconds)
	for _, key in { "UseCombat", "EquipDead", "EquipCombat", "ItemFull", "ItemFullUse" } do
		check(type(L.Text[key]) == "string" and L.Text[key] ~= "", "Config.Loot.Text." .. key .. " is a Korean string", key)
	end
	-- A23-130 (server text verdicts 2026-10-11): the full line says the cap only (no sell / use tip)
	check(L.Text.ItemFull == "%s is full (max %d)." and L.Text.ItemFullUse == L.Text.ItemFull,
		"B7 ItemFull / ItemFullUse: '%s is full (max %d).' (no Forge / Bag tip)", L.Text.ItemFull)
	-- review B3: legendary = exactly 2 x tier 3 (38), below tier 4
	check(C.Weapons[8].Damage == 76 and C.Weapons[8].Damage == 2 * C.Weapons[3].Damage and C.Weapons[8].Damage < C.Weapons[4].Damage,
		"B3 legendary damage 76 = 2 x tier 3, below tier 4", C.Weapons[8].Damage)
	for id, chance in { Move70 = 0.7, Move30 = 0.3, Move10 = 0.1 } do
		local d = L.Items[id]
		check(d and d.Kind == "Transfer" and d.Chance == chance, "transfer scroll " .. id .. " chance", show(d))
	end
	for id, d in L.Items do
		-- Tonic (게임성 개발 3, alchemy): drunk through BuffService's UseTonic, never through UseItem; Treat (⑤ Pet Treat):
		-- fed through TamerService's FeedPet
		check(d.Kind == "Material" or d.Kind == "Enhance" or d.Kind == "Transfer" or d.Kind == "Tonic" or d.Kind == "Treat",
			"item kinds are Material/Enhance/Transfer/Tonic/Treat", id)
		if d.Kind == "Material" then
			check(type(d.Sell) == "number" and d.Sell > 0 and d.Sell == math.floor(d.Sell), "materials have a positive integer Sell price", id)
		end
		check(type(d.Name) == "string" and d.Name ~= "", "items have a Korean display name", id)
		check(table.find(L.Order, id) ~= nil, "every item id is in Loot.Order", id)
	end
	check(#L.Order == count(L.Items), "Loot.Order lists every item exactly once", #L.Order)
	-- A23-45 (2026-10-06): the bat goblin is a woods kind again (candy + the goblin's rows with half its tooth chance and
	-- the tier-4 row); the little ghost = candy + the goblin's scroll / potion rows; the minion a weaker version
	local BAT = {
		{ Item = "Candy", P = 0.45 }, { Item = "GoblinTooth", P = 0.2 },
		{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
		{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
		{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
		{ Weapon = 4, P = 0.001 },
	}
	local GHOST = {
		{ Item = "Candy", P = 0.45 },
		{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
		{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
		{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
	}
	local MINION = {
		{ Item = "Candy", P = 0.3 },
		{ Item = "Enh70", P = 0.008 }, { Item = "Enh30", P = 0.002 }, { Item = "Enh10", P = 0.0005 },
		{ Item = "Move70", P = 0.0025 }, { Item = "Move30", P = 0.0007 }, { Item = "Move10", P = 0.0002 },
		{ Potion = "HP", P = 0.012 }, { Potion = "MP", P = 0.012 },
	}
	check(deepEqual(L.Tables.BatGoblin, BAT),
		"A23-45 BatGoblin rows = Candy 0.45 + GoblinTooth 0.2 + the goblin's scroll / transfer / potion rows + Weapon 4 0.001",
		show(L.Tables.BatGoblin))
	check(deepEqual(L.Tables.LittleGhost, GHOST), "A23-45 LittleGhost rows = candy + the goblin's scroll / potion rows", show(L.Tables.LittleGhost))
	check(deepEqual(L.Tables.GhostMinion, MINION), "A23-45 GhostMinion rows = candy 0.3 + about half the little ghost's rows",
		show(L.Tables.GhostMinion))
	-- A23-27 (2026-10-06): the Pumpkin King's rows (replaces the old scroll rows 0.5 / 0.15 / 0.04 / 0.15)
	local KING = {
		{ Item = "Candy", P = 1, N = 8 },
		{ Item = "Enh70", P = 0.25 }, { Item = "Enh30", P = 0.08 }, { Item = "Enh10", P = 0.02 },
		{ Item = "Move70", P = 0.08 },
		{ Potion = "HP", P = 0.5 }, { Potion = "MP", P = 0.5 },
		{ Weapon = 4, P = 0.05, BelowLevel = { Item = "Candy", N = 3 } },
	}
	check(deepEqual(L.Tables.PumpkinKing, KING),
		"A23-27 PumpkinKing rows = Candy x8, Enh70 0.25 / Enh30 0.08 / Enh10 0.02, Move70 0.08, HP/MP 0.5, T4 0.05 (BelowLevel 3 Candy)",
		show(L.Tables.PumpkinKing))
	for kind, rows in L.Tables do
		for i, row in rows do
			if row.BelowLevel ~= nil then
				local b = row.BelowLevel
				check(row.Weapon ~= nil and type(b) == "table" and L.Items[b.Item] ~= nil and type(b.N) == "number" and b.N >= 1
					and b.N == math.floor(b.N), "A23-27 BelowLevel only on weapon rows, = { Item = real id, N = integer >= 1 }", kind .. "#" .. i)
			end
		end
	end
	-- A23-28 player-facing lines (central text table, Korean + English)
	for key, nArgs in { EquipNeedLevel = 1, WeaponAutoSwap = 2, WeaponUsableNow = 1, WeaponNeedLevel = 1 } do
		local s = C.Text[key]
		local okFmt = type(s) == "string" and pcall(string.format, s, table.unpack(nArgs == 2 and { 30, "x" } or { 5 }))
		check(type(s) == "string" and s ~= "" and okFmt, "Config.Text." .. key .. " is a Korean format string", key)
	end
	check(C.Text.EquipNeedLevel ~= C.Text.WeaponNeedLevel, "EquipNeedLevel (owned weapon) differs from WeaponNeedLevel (purchase)")
	-- Halloween: pumpkin slimes take level-1 slime slots in the season, so they carry the same jackpot
	check(count(L.Jackpot.Monsters) == 2 and L.Jackpot.Monsters.Slime == true and L.Jackpot.Monsters.PumpkinSlime == true,
		"jackpot monsters = { Slime, PumpkinSlime } only", show(L.Jackpot.Monsters))
	check(L.Jackpot.Chance == 1 / 20000 and L.Jackpot.Tier == 8, "jackpot 1/20000 for tier 8", show(L.Jackpot))
	-- A23-15 announcements: Rare (rank 3) and better weapon drops, the jackpot (Legend) and the first +10
	local A = C.Announce
	check(type(A) == "table" and A.MinWeaponGrade == 3, "Config.Announce.MinWeaponGrade is 3 (희귀)", show(A and A.MinWeaponGrade))
	for _, key in { "RareWeapon", "Jackpot", "FirstMax" } do
		check(A and type(A.Text) == "table" and type(A.Text[key]) == "string" and A.Text[key] ~= "",
			"Config.Announce.Text." .. key .. " is a Korean string (AnnounceService ignores unknown keys)", key)
	end
	check(C.WeaponGrades.Common.Rank == 1 and C.WeaponGrades.Fine.Rank == 2 and C.WeaponGrades.Rare.Rank == 3
		and C.WeaponGrades.Epic.Rank == 4 and C.WeaponGrades.Legend.Rank == 5, "weapon grade ranks Common 1 .. Legend 5")
	check(C.WeaponInfo[L.Jackpot.Tier] and C.WeaponInfo[L.Jackpot.Tier].Grade == "Legend", "the jackpot tier's grade is Legend",
		show(C.WeaponInfo[L.Jackpot.Tier]))
	for tier = 1, C.MaxWeaponTier do
		local info = C.WeaponInfo[tier]
		check(info and C.WeaponGrades[info.Grade] ~= nil, "every weapon tier has a real grade id (the announce grade)", tier)
	end
	check(L.FirstScroll.Monster == "BigSlime" and L.FirstScroll.Item == "Enh70", "FirstScroll = BigSlime -> Enh70", show(L.FirstScroll))
	-- A23-14: rebirth keeps every weapon, so the old legendary-only keep list is gone
	check(L.KeepOnRebirth == nil, "Config.Loot.KeepOnRebirth removed (A23-14 rebirth keeps all weapons)", show(L.KeepOnRebirth))
	check(type(L.DuplicateWeaponGold[L.Jackpot.Tier]) == "number" and L.DuplicateWeaponGold[L.Jackpot.Tier] > 0,
		"duplicate legendary has a gold value")
	for kind, rows in L.Tables do
		check(C.MonsterTypes[kind] ~= nil, "drop table kinds are real monster kinds", kind)
		for i, row in rows do
			local kinds = (row.Item and 1 or 0) + (row.Potion and 1 or 0) + (row.Weapon and 1 or 0)
			check(kinds == 1, "each drop row is exactly one of Item / Potion / Weapon", kind .. "#" .. i)
			check(type(row.P) == "number" and row.P > 0 and row.P <= 1, "drop chances are in (0, 1]", kind .. "#" .. i)
			if row.Item then check(L.Items[row.Item] ~= nil, "drop rows name real item ids", row.Item) end
			if row.Potion then check(C.PotionStockKey(row.Potion) ~= nil, "potion rows name HP/MP", row.Potion) end
			if row.Weapon then
				check(C.Weapons[row.Weapon] ~= nil and type(L.DuplicateWeaponGold[row.Weapon]) == "number",
					"weapon rows are real tiers with a duplicate-gold value", kind .. " tier " .. tostring(row.Weapon))
			end
		end
	end
	local D = C.Data.Defaults
	check(type(D.Items) == "table" and next(D.Items) == nil and type(D.WeaponEnhance) == "table" and next(D.WeaponEnhance) == nil
		and type(D.LootFlags) == "table" and next(D.LootFlags) == nil, "Data.Defaults Items / WeaponEnhance / LootFlags are empty tables")
	for _, key in { "Items", "WeaponEnhance", "LootFlags" } do
		check(table.find(C.Data.Mirrored, key) == nil, "table save fields are never mirrored as attributes", key)
	end
	for _, key in { "UseItem", "EquipWeapon", "SellMaterials" } do
		check(type(C.RateLimits[key]) == "number" and C.RateLimits[key] > 0, "RateLimits." .. key .. " is a positive number", C.RateLimits[key])
	end
	local netNames = execute("Net", NET_SOURCE, { game = { GetService = function() return {} end } }).Names
	for _, name in { "UseItem", "EquipWeapon", "SellMaterials", "Inventory" } do
		local n = 0
		for _, x in netNames do if x == name then n += 1 end end
		check(n == 1, "Net registers remote " .. name .. " exactly once", n)
	end
end)

------------------------------------------------------------------ 1. sanitize
runGroup("sanitize", function()
	-- (a) stored garbage that a DataStore can hold (JSON values): wrong types, negatives, fractions, huge, unknown ids
	local saved = deepCopy(DEFAULT_ROW)
	saved.Level, saved.WeaponTier, saved.WeaponOwnedMask = 20, 4, 1 + 8
	local longId = "Old" .. string.rep("x", 70) -- review B10 keeps unknown ids only up to 64 characters
	saved.Items = { Jelly = 5.7, Enh70 = -3, Move70 = 5000, Move30 = "7", Bogus = 3, Bone = 0, KnightCrest = 999.9,
		SlimeCore = {}, GoblinTooth = true, BruteHorn = 1, Move10 = 1e308, Enh30 = -0.5, OldScroll = 1200, Gone = 0,
		[longId] = 4 }
	saved.WeaponEnhance = { 3.9, -2, "x", 99, "5", 1e308, 10, 0.5, 7 }
	saved.LootFlags = { FirstScroll = "yes", Other = true, Z = 1 }
	local f = fixture({ Saved = saved })
	local d = f.Data
	-- review B10: unknown string ids (a renamed / removed item) stay in the SAVE with a sane count, hidden from the client
	local want = { Jelly = 5, Move70 = 999, KnightCrest = 999, BruteHorn = 1, Move10 = 999, Bogus = 3, OldScroll = 999 }
	local wantKnown = { Jelly = 5, Move70 = 999, KnightCrest = 999, BruteHorn = 1, Move10 = 999 }
	check(deepEqual(d.Items, want), "stored garbage Items normalize (floor, 1..999, drop <=0/non-number; unknown ids kept)", show(d.Items))
	local wantEnh = { 3, 0, 0, 10, 0, 10, 10, 0, 7 } -- C1: tier 9's +7 is kept (9 tiers)
	check(deepEqual(d.WeaponEnhance, wantEnh), "stored garbage WeaponEnhance normalizes to 9 tiers clamped 0..10", show(d.WeaponEnhance))
	check(deepEqual(d.LootFlags, { Other = true }), "LootFlags keeps only string keys set to true", show(d.LootFlags))
	-- review B11: no ItemsJson / EnhanceJson attributes (they replicated to every client); the owner-only Inventory remote
	check(f.Player:GetAttribute("ItemsJson") == nil and f.Player:GetAttribute("EnhanceJson") == nil,
		"no ItemsJson / EnhanceJson attributes are published", show({ f.Player:GetAttribute("ItemsJson"), f.Player:GetAttribute("EnhanceJson") }))
	local payload, pushes = f:LastPayload()
	check(pushes == 1, "PlayerReady sends exactly one Inventory push (deferred, coalesced)", pushes)
	check(payload and deepEqual(payload.Items, wantKnown), "Inventory payload Items = known ids only (unknown ids hidden)", show(payload and payload.Items))
	check(payload and type(payload.Enhance) == "table" and #payload.Enhance == f.Config.MaxWeaponTier and deepEqual(payload.Enhance, wantEnh),
		"Inventory payload Enhance is the 9-tier array", show(payload and payload.Enhance))
	local keys = 0
	for k in payload or {} do
		keys += 1
		check(k == "Items" or k == "Enhance" or k == "Seen" or k == "ItemSeq" or k == "WeaponSeq" or k == "Spares",
			"Inventory payload has only Items, Enhance, Seen (+ A23-32 ItemSeq, WeaponSeq, C1 Spares)", tostring(k))
	end
	check(keys == 6, "Inventory payload shape { Items, Enhance, Seen, ItemSeq, WeaponSeq, Spares }", keys)
	check(payload and type(payload.Seen) == "table" and next(payload.Seen) == nil, "P7 no kills yet: payload Seen = {}", show(payload and payload.Seen))
	check(f.Player:GetAttribute("WeaponEnhance") == 10, "WeaponEnhance attribute = +N of the equipped tier (4)", f.Player:GetAttribute("WeaponEnhance"))
	-- unknown ids can never be used, sold or given
	f.Notices, f.Draws = {}, 0
	f:Use("Bogus", 1)
	f:Use("OldScroll", 1, 2)
	check(d.Items.Bogus == 3 and d.Items.OldScroll == 999 and f.Draws == 0, "unknown saved ids cannot be used (kept, no roll)")
	check(f:Give("Bogus", 2) == 0 and d.Items.Bogus == 3, "DebugGive refuses unknown ids")
	local before = deepCopy({ d.Items, d.WeaponEnhance, d.LootFlags })
	f.PS.PlayerReady:Fire(f.Player, d)
	check(deepEqual(before, { d.Items, d.WeaponEnhance, d.LootFlags }), "sanitize is idempotent")
	check(f.DS.Save(f.Player, false) == true, "sanitized save data survives the DataStore JSON round trip")
	local row = f.Rows["P_" .. f.UserId]
	check(deepEqual(row.Items, want) and deepEqual(row.WeaponEnhance, wantEnh) and deepEqual(row.LootFlags, { Other = true }),
		"saved row equals the sanitized tables (unknown ids preserved)", show(row.Items))
	f:Pushes()

	-- (b) live garbage that only a bug could create: NaN, +-inf, non-string keys, keys outside 1..8, fractional tiers
	d.Items = { Jelly = 0 / 0, Enh70 = math.huge, Enh30 = -math.huge, [1] = 4, [true] = 2, Move70 = 12.9, Bone = -0.5, Move10 = 1000 }
	d.WeaponEnhance = { [1] = 0 / 0, [2] = math.huge, [3] = -math.huge, [4] = 4.5, [8] = 11, [0] = 3, [-1] = 2, [9] = 7, [10] = 5, [2.5] = 6 }
	d.LootFlags = { FirstScroll = 1, [1] = true, Keep = true, Bad = "true" }
	f.PS.PlayerReady:Fire(f.Player, d)
	check(deepEqual(d.Items, { Move70 = 12, Move10 = 999 }), "NaN/inf/non-string-key Items are dropped, >cap capped", show(d.Items))
	check(deepEqual(d.WeaponEnhance, { 0, 0, 0, 4, 0, 0, 0, 10, 7 }), "NaN/inf/out-of-range WeaponEnhance entries normalize", show(d.WeaponEnhance))
	local keys = 0
	for k in d.WeaponEnhance do
		keys += 1
		check(type(k) == "number" and k >= 1 and k <= 9 and k == math.floor(k), "WeaponEnhance keys are exactly tiers 1..9", tostring(k))
	end
	check(keys == f.Config.MaxWeaponTier, "WeaponEnhance always has MaxWeaponTier entries", keys)
	check(deepEqual(d.LootFlags, { Keep = true }), "LootFlags drops non-true values and non-string keys", show(d.LootFlags))
	local again = f:LastPayload()
	check(again and again.Items.Move70 == 12 and again.Items.Move10 == 999, "Inventory republished after sanitize", show(again and again.Items))

	-- (c) wrong container types (stored) and a legacy row without the fields
	for label, row in {
		WrongTypes = { Items = "abc", WeaponEnhance = 7, LootFlags = "x" },
		Legacy = {},
	} do
		local s = deepCopy(DEFAULT_ROW)
		for k, v in row do s[k] = v end
		local g = fixture({ Saved = s })
		check(deepEqual(g.Data.Items, {}) and deepEqual(g.Data.WeaponEnhance, { 0, 0, 0, 0, 0, 0, 0, 0, 0 })
			and deepEqual(g.Data.LootFlags, {}), label .. ": Items {} / WeaponEnhance 9 zeros / LootFlags {}", show(g.Data.WeaponEnhance))
		check(g.Player:GetAttribute("WeaponEnhance") == 0, label .. ": WeaponEnhance attribute 0")
	end
	-- (d) brand-new player
	local n = fixture({ Fresh = true })
	local np = n:LastPayload()
	check(deepEqual(n.Data.Items, {}) and #n.Data.WeaponEnhance == 9 and n.Player:GetAttribute("WeaponEnhance") == 0
		and np and deepEqual(np, { Items = {}, Enhance = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }, Seen = {}, ItemSeq = {},
			WeaponSeq = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }, Spares = {} }),
		"new player: empty items, 9 tiers, Inventory pushed and WeaponEnhance attribute 0", show(np))
	-- a burst of changes in one frame is one push; a player who left gets none; a real spawn resends (safety net)
	n:Give("Jelly", 1); n:Give("Jelly", 1); n:Give("Bone", 1)
	local burst, burstCount = n:LastPayload()
	check(burstCount == 1 and burst and burst.Items.Jelly == 2 and burst.Items.Bone == 1, "several changes in one frame = one Inventory push",
		show({ burstCount, burst and burst.Items }))
	n.PS.CharacterSpawned:Fire(n.Player, nil, nil, false)
	local _, spawnCount = n:LastPayload()
	n.PS.CharacterSpawned:Fire(n.Player, nil, nil, true)
	local _, cosmeticCount = n:LastPayload()
	check(spawnCount == 1 and cosmeticCount == 0, "a real CharacterSpawned resends the Inventory; a cosmetic respawn does not",
		show({ spawnCount, cosmeticCount }))
	n:Give("Jelly", 1)
	n.Player.Parent = nil
	local _, leftCount = n:LastPayload()
	check(leftCount == 0, "no Inventory push to a player who left before the frame ended", leftCount)
	n.Player.Parent = n.World.Players
	n.Loot.Refresh(n.Player)
	local refreshed, refreshCount = n:LastPayload()
	check(refreshCount == 1 and refreshed and refreshed.Items.Jelly == 3, "LootService.Refresh re-sends the owner's Inventory", refreshCount)
	-- (e) RollKill repairs a missing Items / WeaponEnhance table itself; DebugGive respects the cap
	n.Data.Items, n.Data.WeaponEnhance = nil, nil
	n.ScriptConst = 0
	local g = n:Roll("Slime")
	-- (Lv1: the C2 tier-3 row pays its BelowLevel jelly too)
	check(type(n.Data.Items) == "table" and #n.Data.WeaponEnhance == 9 and n.Data.Items.Jelly == 2 and #g > 0,
		"RollKill sanitizes missing tables before granting", show(n.Data.Items))
	n.ScriptConst = nil
	local had = n.Data.Items.Jelly
	check(n:Give("Jelly", 5000) == 999 - had and n.Data.Items.Jelly == 999, "DebugGive caps at ItemCap", n.Data.Items.Jelly)
end)

------------------------------------------------------------------ 2. RollKill
runGroup("rollkill", function()
	local f = fixture()
	local L = f.L
	f.ScriptConst = 0.999999
	-- one call = one roll: one draw per table row (+1 jackpot draw for jackpot kinds); A23-27: a BelowLevel weapon row
	-- (the king's T4) is not drawn for a killer below that weapon's MinLevel. Checked at Lv1 and at Lv12+.
	for _, level in { 1, 12 } do
		f:Set("Level", level)
		for kind, rows in L.Tables do
			f.Draws = 0
			local g = f:Roll(kind)
			local want = #rows + (L.Jackpot.Monsters[kind] and 1 or 0) - belowLevelRows(f, kind, level)
			check(f.Draws == want, "one RollKill = one draw per row (+ jackpot draw; a BelowLevel row below its MinLevel draws nothing)",
				kind .. " Lv" .. level .. " draws " .. f.Draws .. " want " .. want)
			check(type(g) == "table", "RollKill returns the gained list", kind)
		end
	end
	check(belowLevelRows(f, "PumpkinKing", 1) == 1 and belowLevelRows(f, "PumpkinKing", 12) == 0,
		"the Pumpkin King has exactly one BelowLevel row (T4, MinLevel 12)")
	f:Set("Level", 1)
	f.Draws = 0
	f:Kill("Slime")
	local slimeDraws = #L.Tables.Slime + 1 - belowLevelRows(f, "Slime", 1)
	check(f.Draws == slimeDraws, "one MonsterKilled signal = exactly one roll", f.Draws)
	f.Draws = 0
	f:Kill("Slime", { Auto = true, SkillHit = true, Personal = true })
	check(f.Draws == slimeDraws, "auto / skill / personal kills roll like any kill", f.Draws)
	-- 검수 2026-10-09: a free rider's share (MonsterService MinorShare, info.Minor) rolls nothing
	f.Draws = 0
	f:Kill("CaptainClatter", { Minor = true })
	check(f.Draws == 0, "info.Minor: no drop rows, no jackpot", f.Draws)

	-- every contributor gets an own roll (MonsterService fires once per contributor)
	local p2, d2 = f:Join(f.UserId + 100000)
	local n = #L.Tables.Slime + 1 - belowLevelRows(f, "Slime", math.floor(tonumber(f.Data.Level) or 1))
	local jellyBefore = f:Count("Jelly") -- the every-kind loop above may have paid Jelly (King Slime)
	local script = {}
	for i = 1, n do script[i] = 0 end
	for i = 1, n do script[n + i] = 0.999999 end
	f.Script, f.Draws = script, 0
	f:Kill("Slime")
	f:Kill("Slime", nil, p2)
	check(f.Draws == 2 * n and #f.Script == 0, "two contributors = two independent rolls", f.Draws)
	-- (below Lv5 each also gets the C2 tier-3 row's BelowLevel jelly, without a draw)
	local bl = belowLevelRows(f, "Slime", math.floor(tonumber(f.Data.Level) or 1)) > 0 and 1 or 0
	check(f:Count("Jelly") - jellyBefore == 1 + bl and (d2.Items.Jelly or 0) == bl, "contributor rolls are independent (own result each)",
		show({ f:Count("Jelly") - jellyBefore, d2.Items.Jelly }))
	f.Script = {}

	-- unknown / malformed kinds give nothing
	local before = f:State()
	for _, kind in { "Dragon", "", "slime", "SLIME" } do
		f.Draws = 0
		local g = f:Roll(kind)
		check(type(g) == "table" and #g == 0 and f.Draws == 0, "unknown Kind gives nothing and draws nothing", kind)
	end
	for _, info in { { Kind = 5 }, { Kind = nil }, "Slime", 7 } do
		check(f.Loot.RollKill(f.Player, info) == nil, "non-string Kind / non-table info returns nil", show(info))
	end
	check(deepEqual(before, f:State()), "malformed kills changed nothing")

	-- A23-27: the king's T4 row is rolled only at Level >= 12 (the weapon's MinLevel, the same rule as equipping); below
	-- it the row pays its BelowLevel item (3 candies) with no draw. RollKill always uses the killer's saved Level (a clone
	-- of the caller's info gets it); DebugSimulate (no Level) rolls the row as before (lootroll group).
	do
		local k = fixture()
		local king = L.Tables.PumpkinKing
		k.Data.LootFlags.FirstScroll = true
		local function kingRoll(level, const, golden, info)
			k:Set("Level", level)
			k.Data.Items, k.Data.HPPotionCount, k.Data.MPPotionCount, k.Data.WeaponOwnedMask = {}, 0, 0, 1
			k.ScriptConst, k.Draws, k.Notices, k.Announces = const, 0, {}, {}
			local g
			if info then g = k.Loot.RollKill(k.Player, info) else g = k:Roll("PumpkinKing", golden) end
			k.ScriptConst = nil
			return g, k:Gained(g, "Item", "Candy"), k:Gained(g, "Weapon", 4), k.Draws
		end
		local T4 = bit32.lshift(1, 3)
		for _, level in { 1, 11 } do
			local g, candy, weapon, draws = kingRoll(level, 0)
			check(weapon == 0 and not bit32.btest(k.Data.WeaponOwnedMask, T4) and #k.Announces == 0 and #k.GoldLog == 0,
				"A23-27 below Lv12 the king's T4 row never drops the weapon (every draw a hit)", "Lv" .. level .. " " .. show(g))
			check(candy == 8 + 3 and k.Data.Items.Candy == 11, "A23-27 below Lv12 the king's T4 row pays its BelowLevel 3 candies (+ the 8-candy row)",
				"Lv" .. level .. " candy " .. candy)
			check(draws == #king - 1, "A23-27 below Lv12 the BelowLevel row uses no draw (rows - 1)", "Lv" .. level .. " draws " .. draws)
			g, candy, weapon, draws = kingRoll(level, 0.999999)
			check(candy == 11 and weapon == 0 and draws == #king - 1, "A23-27 below Lv12 the 3 candies need no lucky draw (every draw a miss)",
				"Lv" .. level .. " " .. show({ candy, weapon, draws }))
			g, candy = kingRoll(level, 0.999999, true)
			check(candy == 11, "A23-27 a golden king below Lv12: still exactly 3 BelowLevel candies (N fixed, no draw)", candy)
		end
		for _, level in { 12, 40 } do
			local g, candy, weapon, draws = kingRoll(level, 0)
			check(weapon == 1 and bit32.btest(k.Data.WeaponOwnedMask, T4) and candy == 8 and draws == #king,
				"A23-27 at Lv12+ the king's T4 row is drawn (hit = the weapon, no BelowLevel candies)", "Lv" .. level .. " " .. show(g))
			g, candy, weapon, draws = kingRoll(level, 0.999999)
			check(weapon == 0 and candy == 8 and draws == #king, "A23-27 at Lv12+ a missed T4 draw pays nothing extra", "Lv" .. level .. " " .. show({ candy, weapon, draws }))
		end
		-- the caller cannot pass its own Level: RollKill clones info and sets Level from the save
		local info = { Kind = "PumpkinKing", Golden = false, Level = 99 }
		local _, candy, weapon, draws = kingRoll(1, 0, nil, info)
		check(weapon == 0 and candy == 11 and draws == #king - 1, "A23-27 RollKill uses the killer's saved Level, not info.Level from the caller",
			show({ candy, weapon, draws }))
		check(info.Level == 99 and count(info) == 3, "RollKill never writes the caller's kill info (clone)", show(info))
		local plain = { Kind = "PumpkinKing", Golden = false }
		kingRoll(1, 0.999999, nil, plain)
		check(plain.Level == nil and count(plain) == 2, "the caller's kill info gets no Level field (clone)", show(plain))
		-- through the real MonsterKilled signal
		k:Set("Level", 1)
		k.Data.Items, k.ScriptConst = {}, 0
		k:Kill("PumpkinKing")
		k.ScriptConst = nil
		check(k.Data.Items.Candy == 11 and not bit32.btest(k.Data.WeaponOwnedMask, T4), "A23-27 a Lv1 MonsterKilled king kill: 11 candies, no T4",
			show(k.Data.Items))
	end

	-- exact thresholds: a row drops iff draw < P (x GoldenMult when info.Golden == true)
	local t = fixture()
	t.Data.LootFlags.FirstScroll = true
	t.Data.LootFlags.FirstWeapon = true -- C2: the first Prince's weapon is not a row
	t:Set("Level", 50) -- every row draws (the C2 tier-3 rows have a BelowLevel)
	for _, kind in { "Slime", "BigSlime", "Goblin" } do
		local rows = L.Tables[kind]
		for i, row in rows do
			for _, golden in { false, true } do
				local p = math.min(1, row.P * (golden and L.GoldenMult or 1))
				if p < 1 then
					for _, case in { { p - 1e-9, true }, { p, false } } do
						local script2 = {}
						for j in rows do script2[j] = j == i and case[1] or 0.999999 end
						if L.Jackpot.Monsters[kind] then table.insert(script2, 0.999999) end
						t.Script = script2
						t.Data.Items, t.Data.HPPotionCount, t.Data.MPPotionCount, t.Data.WeaponOwnedMask = {}, 0, 0, 1
						local g = t:Roll(kind, golden)
						t.Script = {}
						local got = (row.Item and t:Gained(g, "Item", row.Item)) or (row.Potion and t:Gained(g, "Potion", row.Potion))
							or (row.Weapon and t:Gained(g, "Weapon", row.Weapon)) or 0
						check((got > 0) == case[2], "row drops iff draw < P" .. (golden and " x GoldenMult" or ""),
							kind .. "#" .. i .. " draw " .. case[1] .. " got " .. got)
					end
				end
			end
		end
	end
	-- Golden must be exactly true
	local jelly = rowIndex(L, "Slime", "Item", "Jelly")
	for golden, want in { [true] = 1, ["true"] = 0, [1] = 0 } do
		local script3 = {}
		for j in L.Tables.Slime do script3[j] = j == jelly and 0.31 or 0.999999 end
		table.insert(script3, 0.999999)
		t.Script, t.Data.Items = script3, {}
		t.Loot.RollKill(t.Player, { Kind = "Slime", Golden = golden })
		t.Script = {}
		check((t.Data.Items.Jelly or 0) == want, "GoldenMult applies only for Golden == true", tostring(golden))
	end

	-- drop distribution over many seeded rolls (Items / potions / mask reset each roll so caps never interfere)
	local function sample(kind, golden, nRolls, seed)
		local s = fixture()
		s.Data.LootFlags.FirstScroll = true
		s.Data.LootFlags.FirstWeapon = true -- C2
		s:Set("Level", 50) -- every row draws (C2 BelowLevel rows)
		math.randomseed(seed)
		local counts, events = {}, {}
		local info = { Kind = kind, Golden = golden }
		for _ = 1, nRolls do
			s.Data.Items, s.Data.HPPotionCount, s.Data.MPPotionCount, s.Data.WeaponOwnedMask = {}, 0, 0, 1
			s.Notices, s.FxLog = {}, {}
			for _, e in s.Loot.RollKill(s.Player, info) do
				local key = e.Item or (e.Potion and "Potion" .. e.Potion) or ("Weapon" .. tostring(e.Weapon))
				counts[key] = (counts[key] or 0) + (e.N or 1)
				events[key] = (events[key] or 0) + 1
			end
		end
		local tag = kind .. (golden and "(golden)" or "")
		for _, row in L.Tables[kind] do
			local key = row.Item or (row.Potion and "Potion" .. row.Potion) or ("Weapon" .. tostring(row.Weapon))
			local p = math.min(1, row.P * (golden and L.GoldenMult or 1))
			local hits = events[key] or 0
			stat(tag .. "." .. key, hits, nRolls, p)
			check(within(hits, nRolls, p), "drop rate within 5 sigma of Config.Loot.Tables P" .. (golden and " x 3 (capped at 1)" or ""),
				tag .. "." .. key .. " " .. hits .. "/" .. nRolls .. " expected " .. p)
			if row.N and row.N > 1 then
				check(counts[key] == hits * row.N, "rows with N > 1 grant N per drop", key)
			end
		end
		if L.Jackpot.Monsters[kind] then
			local p = math.min(1, L.Jackpot.Chance * (golden and L.GoldenMult or 1))
			local hits = events["Weapon" .. L.Jackpot.Tier] or 0
			stat(tag .. ".Jackpot", hits, nRolls, p)
			check(within(hits, nRolls, p), "jackpot rate within 5 sigma of 1/20000" .. (golden and " x 3" or ""), hits .. "/" .. nRolls)
		end
	end
	sample("Slime", false, math.floor(300000 * SAMPLE_SCALE), 101)
	sample("Slime", true, math.floor(40000 * SAMPLE_SCALE), 202)
	sample("BigSlime", true, math.floor(4000 * SAMPLE_SCALE), 303)
	sample("SkeletonKnight", false, math.floor(20000 * SAMPLE_SCALE), 404)

	-- item cap 999: nothing above the cap, a notice when it is full
	local c = fixture()
	c.Data.LootFlags.FirstScroll = true
	c:Give("Jelly", 999)
	c.Notices = {}
	local g = c:Force("Slime", { [jelly] = true })
	local itemDef = L.Items.Jelly
	local fullText = string.format(L.Text.ItemFull, itemDef.Name, L.ItemCap)
	local function fullNotices(text)
		local n, kinds = 0, {}
		for _, e in c.Notices do if e.Text == text then n += 1; kinds[e.Kind] = true end end
		return n, kinds
	end
	check(c:Count("Jelly") == 999 and c:Gained(g, "Item", "Jelly") == 0, "full item stays at 999 and is not reported as gained", c:Count("Jelly"))
	local nFull, kinds = fullNotices(fullText)
	check(nFull == 1 and kinds.info == true, "full material sends the ItemFull notice (kind info, mentions the blacksmith)", nFull)
	-- review B7: at most once per item id per FullNoticeSeconds
	for _ = 1, 5 do c:Force("Slime", { [jelly] = true }); c.Now += 10 end
	check(fullNotices(fullText) == 1, "ItemFull repeats at most once per item id per 5 minutes", fullNotices(fullText))
	c.Now += L.FullNoticeSeconds
	c.Data.Items.Jelly = 998
	local bigJelly = rowIndex(L, "BigSlime", "Item", "Jelly")
	g = c:Force("BigSlime", { [bigJelly] = true })
	check(c:Count("Jelly") == 999 and c:Gained(g, "Item", "Jelly") == 1, "partial room grants only up to the cap and reports the real count",
		show({ c:Count("Jelly"), c:Gained(g, "Item", "Jelly") }))
	check(fullNotices(fullText) == 2, "after 5 minutes a partly-fitting drop (998 + 2) sends the ItemFull notice again", fullNotices(fullText))
	-- scrolls cannot be sold: their full notice points at the item list; another id has its own 5-minute window
	local enhRow = rowIndex(L, "Slime", "Item", "Enh70")
	c:Give("Enh70", 999)
	c:Force("Slime", { [enhRow] = true })
	local scrollFull = string.format(L.Text.ItemFullUse, L.Items.Enh70.Name, L.ItemCap)
	check(fullNotices(scrollFull) == 1 and c:Count("Enh70") == 999, "full scroll sends ItemFullUse (own window per item id)", fullNotices(scrollFull))

	-- potions go to the stock counters (not Items) and respect the 99 cap
	local hp, mp = rowIndex(L, "Slime", "Potion", "HP"), rowIndex(L, "Slime", "Potion", "MP")
	local pf = fixture()
	pf:Set("Level", 50) -- C2: no BelowLevel jelly
	g = pf:Force("Slime", { [hp] = true, [mp] = true })
	check(pf.Data.HPPotionCount == 1 and pf.Data.MPPotionCount == 1 and pf.Player:GetAttribute("HPPotionCount") == 1
		and pf.Player:GetAttribute("MPPotionCount") == 1, "potion drops add 1 to HP/MPPotionCount (saved + mirrored)")
	check(pf:Gained(g, "Potion", "HP") == 1 and pf:Gained(g, "Potion", "MP") == 1 and next(pf.Data.Items) == nil,
		"potions are reported as gained and never enter Items", show(pf.Data.Items))
	local cap = pf.Config.Vitals.PotionInventoryCap
	pf:Set("HPPotionCount", cap)
	pf.Notices = {}
	g = pf:Force("Slime", { [hp] = true })
	check(pf.Data.HPPotionCount == cap and pf:Gained(g, "Potion", "HP") == 0, "potion at PotionInventoryCap is not granted", pf.Data.HPPotionCount)
	local potionFull = string.format(L.Text.PotionFull, L.Text.Potion.HP)
	check(pf:Noticed(potionFull) == 1, "full potion stock sends the PotionFull notice")
	for _ = 1, 3 do pf:Force("Slime", { [hp] = true }); pf.Now += 30 end
	check(pf:Noticed(potionFull) == 1, "PotionFull is throttled like items (once per 5 minutes per potion kind)", pf:Noticed(potionFull))
	pf.Now += L.FullNoticeSeconds
	pf:Force("Slime", { [hp] = true })
	check(pf:Noticed(potionFull) == 2, "PotionFull shows again after 5 minutes", pf:Noticed(potionFull))

	-- FirstScroll: exactly one Enh70 from the first BigSlime, never again (also across save / reload)
	local fs = fixture()
	fs.ScriptConst = 0.999999
	for _ = 1, 20 do fs:Kill("Slime") end
	check(fs:Count("Enh70") == 0 and fs.Data.LootFlags.FirstScroll ~= true, "slime kills never trigger the first-scroll guarantee")
	fs.FxLog = {}
	fs:Kill("BigSlime")
	check(fs:Count("Enh70") == 1 and fs.Data.LootFlags.FirstScroll == true, "first BigSlime kill guarantees exactly one Enh70", fs:Count("Enh70"))
	check(fs:Noticed(L.Text.FirstScroll) == 1, "first-scroll hint shown once")
	local firstNote = nil
	for _, e in fs.Notices do if e.Text == L.Text.FirstScroll then firstNote = e end end
	check(firstNote and firstNote.Duration == L.FirstScroll.NoticeSeconds and firstNote.Duration == 6,
		"first-scroll hint stays 6 s (Config.Loot.FirstScroll.NoticeSeconds)", firstNote and firstNote.Duration)
	local lootFx = fs.FxLog[#fs.FxLog]
	check(lootFx and lootFx.Kind == "Loot" and lootFx.Data.First == true, "that kill's Loot Fx carries First = true (client skips its own toast)",
		show(lootFx and lootFx.Data and lootFx.Data.First))
	fs.FxLog = {}
	fs.ScriptConst = 0 -- every row drops, so a later Loot Fx surely exists
	fs:Kill("BigSlime")
	fs.ScriptConst = 0.999999
	local laterFx = fs.FxLog[#fs.FxLog]
	check(laterFx and laterFx.Kind == "Loot" and laterFx.Data.First == nil, "later Loot Fx never carries First", show(laterFx and laterFx.Data.First))
	fs.Data.Items.Enh70 = 1
	for _ = 1, 50 do fs:Kill("BigSlime") end
	check(fs:Count("Enh70") == 1 and fs:Noticed(L.Text.FirstScroll) == 1, "the guarantee is never paid twice in a session", fs:Count("Enh70"))
	fs:Release()
	check(fs.Rows["P_" .. fs.UserId].LootFlags.FirstScroll == true, "LootFlags.FirstScroll is in the saved record")
	local re = fixture({ Rows = fs.Rows, UserId = fs.UserId })
	re.ScriptConst = 0.999999
	check(re.Data.LootFlags.FirstScroll == true and re:Count("Enh70") == 1, "LootFlags and the scroll survive reload")
	for _ = 1, 10 do re:Kill("BigSlime") end
	check(re:Count("Enh70") == 1 and re:Noticed(L.Text.FirstScroll) == 0, "no second guarantee after reload", re:Count("Enh70"))
	local had = fixture()
	had.ScriptConst = 0.999999
	had:Give("Enh70", 4)
	had:Kill("BigSlime", { Golden = true })
	check(had:Count("Enh70") == 5, "first guarantee adds exactly one even when scrolls are already owned / golden", had:Count("Enh70"))
	-- review B8: a full Enh70 stack cannot take the guaranteed scroll -> the guarantee stays for a later king slime
	local full = fixture()
	full.ScriptConst = 0.999999
	full:Give("Enh70", full.L.ItemCap)
	full:Kill("BigSlime")
	check(full:Count("Enh70") == full.L.ItemCap and full.Data.LootFlags.FirstScroll ~= true and full:Noticed(L.Text.FirstScroll) == 0,
		"B8 full Enh70 stack: no grant, FirstScroll flag NOT set, no guide", show(full.Data.LootFlags))
	full.Data.Items.Enh70 = full.L.ItemCap - 1
	full:Kill("BigSlime")
	check(full:Count("Enh70") == full.L.ItemCap and full.Data.LootFlags.FirstScroll == true and full:Noticed(L.Text.FirstScroll) == 1,
		"B8 the kept guarantee pays on the next king slime once there is room", full:Count("Enh70"))
	full:Kill("BigSlime")
	check(full:Noticed(L.Text.FirstScroll) == 1, "B8 the guarantee is still paid only once", full:Noticed(L.Text.FirstScroll))

	-- jackpot exists only for Slime kinds (the level-1 slime and its seasonal stand-in, the pumpkin slime)
	for kind in L.Tables do
		if kind ~= "Slime" and kind ~= "PumpkinSlime" then
			local j = fixture()
			j.Data.LootFlags.FirstScroll = true
			j.ScriptConst, j.Draws = 0, 0
			j:Roll(kind, true)
			check(not bit32.btest(j.Data.WeaponOwnedMask, bit32.lshift(1, L.Jackpot.Tier - 1)) and #j.All == 0
				and #j:Announced("Jackpot") == 0 and j.Draws == #L.Tables[kind] - belowLevelRows(j, kind, j.Data.Level),
				"no jackpot roll for non-slime kinds", kind .. " draws " .. j.Draws)
		end
	end
	local js = fixture()
	js:Set("Level", 50) -- C2: every slime row draws
	js:Force("Slime", nil, true, false, { Auto = true, Personal = true })
	check(bit32.btest(js.Data.WeaponOwnedMask, bit32.lshift(1, L.Jackpot.Tier - 1)), "slime jackpot also pays for auto / personal kills")
	local jp = fixture()
	jp:Set("Level", 50)
	jp:Force("PumpkinSlime", nil, true, false, { Auto = true })
	check(bit32.btest(jp.Data.WeaponOwnedMask, bit32.lshift(1, L.Jackpot.Tier - 1)), "pumpkin slime carries the slime jackpot")

	-- jackpot thresholds 1/20000 and 3/20000
	for _, case in { { false, L.Jackpot.Chance - 1e-12, true }, { false, L.Jackpot.Chance + 1e-12, false },
		{ true, L.Jackpot.Chance * 3 - 1e-12, true }, { true, L.Jackpot.Chance * 3 + 1e-12, false } } do
		local j = fixture()
		j:Set("Level", 50)
		local script4 = {}
		for i in L.Tables.Slime do script4[i] = 0.999999 end
		table.insert(script4, case[2])
		j.Script = script4
		j:Roll("Slime", case[1])
		check(bit32.btest(j.Data.WeaponOwnedMask, 128) == case[3], "jackpot threshold exact (golden x3)", show(case))
	end

	-- items are never lost on death / leave
	local keep = fixture()
	keep:Give("Jelly", 7)
	keep:Give("Enh30", 2)
	keep.Data.WeaponEnhance[1] = 3
	local snap = deepCopy({ keep.Data.Items, keep.Data.WeaponEnhance })
	keep.PS.CharacterDied:Fire(keep.Player)
	keep.PS.PlayerLeaving:Fire(keep.Player, keep.Data)
	check(deepEqual(snap, { keep.Data.Items, keep.Data.WeaponEnhance }), "death / leave handlers never touch Items or enhancement")
end)

------------------------------------------------------------------ 2a. A23-22 bully drop penalty (review item 3)
-- While the player's BullyStacks attribute is >= 1, RollKill rolls a clone of the kill info with DropMult =
-- Config.Bully.Penalty.DropMult: every drop row AND the slime jackpot use P (Chance) x GoldenMult x 0.5, capped at 1.
-- The first king-slime scroll is a one-time grant before any roll, so it stays guaranteed and whole. BullyStacks 0 (the
-- last stack decayed) is the normal table again; the penalty is flat (x0.5 at any level), never x0.5 per stack.
runGroup("bully", function()
	local HALF = 0.5 -- A23-22: 드랍률 x0.5 (대박 확률도 절반)
	local t = fixture()
	local L, C = t.L, t.Config
	C.Features.Crafting = true -- C1 review: the boss craft materials' rows draw like every other row here
	local pen = C.Bully and C.Bully.Penalty
	check(type(pen) == "table" and pen.DropMult == HALF, "A23-22 Config.Bully.Penalty.DropMult is 0.5", show(pen))
	local jackpotBit = bit32.lshift(1, L.Jackpot.Tier - 1)
	t.Data.LootFlags.FirstScroll = true
	-- A23-27: a Lv50 killer, so every row (also the king's BelowLevel T4 row) is a real draw here; below Lv12 see the end
	t:Set("Level", 50)
	local function setStacks(n) t.Player:SetAttribute("BullyStacks", n) end
	-- one scripted roll: row `index` draws `draw`, every other row misses; the jackpot draw is `jackpotDraw` (else a miss).
	-- Items / potions / owned weapons reset first so caps and duplicates never hide a drop.
	local function roll(kind, golden, index, draw, jackpotDraw)
		local script = {}
		for j in L.Tables[kind] do script[j] = (j == index) and draw or 0.999999 end
		if L.Jackpot.Monsters[kind] then table.insert(script, jackpotDraw or 0.999999) end
		t.Script, t.Draws = script, 0
		t.Data.Items, t.Data.HPPotionCount, t.Data.MPPotionCount, t.Data.WeaponOwnedMask = {}, 0, 0, 1
		local g = t:Roll(kind, golden)
		local left = #t.Script
		t.Script = {}
		return g, left
	end
	local function gotRow(g, row)
		return (row.Item and t:Gained(g, "Item", row.Item)) or (row.Potion and t:Gained(g, "Potion", row.Potion))
			or (row.Weapon and t:Gained(g, "Weapon", row.Weapon)) or 0
	end
	local function jackpotPaid() return bit32.btest(t.Data.WeaponOwnedMask, jackpotBit) end

	-- rows: drop iff draw < min(1, P x GoldenMult? x factor); with the penalty the old (full) threshold no longer drops
	local function rowThresholds(label, factor)
		local penalized = factor ~= 1
		for kind, rows in L.Tables do
			local drawsWant = #rows + (L.Jackpot.Monsters[kind] and 1 or 0)
			for i, row in rows do
				for _, golden in { false, true } do
					local mult = golden and L.GoldenMult or 1
					local p = math.min(1, row.P * (mult * factor))
					local where = kind .. "#" .. i .. (golden and " golden" or "")
					local name = label .. ": a " .. (golden and "golden " or "") .. "row drops iff draw < P"
						.. (golden and " x GoldenMult" or "") .. (penalized and " x 0.5" or "") .. " (capped at 1)"
					if p < 1 then
						local g, left = roll(kind, golden, i, p - 1e-9)
						check(gotRow(g, row) > 0, name, where .. " draw just below " .. p .. " dropped nothing")
						check(left == 0 and t.Draws == drawsWant, label .. ": one draw per row (+ jackpot) per kill",
							where .. " draws " .. t.Draws .. " want " .. drawsWant .. " unused " .. left)
						g = roll(kind, golden, i, p)
						check(gotRow(g, row) == 0, name, where .. " draw " .. p .. " still dropped")
						if penalized then
							local full = math.min(1, row.P * mult)
							g = roll(kind, golden, i, full - 1e-9)
							check(gotRow(g, row) == 0, label .. ": the unpenalized chance P" .. (golden and " x GoldenMult" or "")
								.. " no longer drops", where .. " draw " .. (full - 1e-9) .. " dropped (penalty ignored)")
						end
					else
						local g = roll(kind, golden, i, 0.999999)
						check(gotRow(g, row) > 0, name, where .. " capped chance 1 did not drop")
					end
				end
			end
		end
	end
	-- jackpot: pays iff draw < Chance x GoldenMult? x factor (Slime and PumpkinSlime)
	local function jackpotThresholds(label, factor)
		local penalized = factor ~= 1
		for kind in L.Jackpot.Monsters do
			for _, golden in { false, true } do
				local mult = golden and L.GoldenMult or 1
				local pj = math.min(1, L.Jackpot.Chance * (mult * factor))
				local name = label .. ": " .. (golden and "a golden " or "the ") .. "jackpot pays iff draw < Chance"
					.. (golden and " x GoldenMult" or "") .. (penalized and " x 0.5" or "")
				for _, case in { { pj - 1e-12, true }, { pj, false } } do
					roll(kind, golden, nil, nil, case[1])
					check(jackpotPaid() == case[2], name, kind .. (golden and " golden" or "") .. " draw " .. case[1]
						.. " paid " .. tostring(jackpotPaid()))
				end
				if penalized then
					local full = L.Jackpot.Chance * mult
					roll(kind, golden, nil, nil, full - 1e-12)
					check(not jackpotPaid(), label .. ": the unpenalized jackpot chance" .. (golden and " x GoldenMult" or "")
						.. " no longer pays", kind .. " draw " .. (full - 1e-12) .. " paid (jackpot not halved)")
				end
			end
		end
	end

	-- BullyStacks 1: rows and the jackpot at half chance
	setStacks(1)
	rowThresholds("BullyStacks 1", HALF)
	jackpotThresholds("BullyStacks 1", HALF)
	-- the caller's info (MonsterService's MonsterKilled table) is never written: RollKill rolls a clone
	local info = { Kind = "Slime", Golden = false }
	t.ScriptConst = 0.999999
	t.Loot.RollKill(t.Player, info)
	t.ScriptConst = nil
	check(info.DropMult == nil and count(info) == 2, "BullyStacks 1: the caller's kill info is never given DropMult (cloned)", show(info))
	-- flat penalty while BullyStacks >= 1 (A23-22), not x0.5 per stack
	setStacks(3)
	local jelly = rowIndex(L, "Slime", "Item", "Jelly")
	local jellyRow = L.Tables.Slime[jelly]
	local pJelly = jellyRow.P * HALF
	local g = roll("Slime", false, jelly, pJelly - 1e-9)
	local below = gotRow(g, jellyRow) > 0
	g = roll("Slime", false, jelly, pJelly)
	check(below and gotRow(g, jellyRow) == 0, "BullyStacks 3: still exactly x0.5 for rows (the drop penalty does not stack)",
		"Slime Jelly below " .. tostring(below) .. " at " .. pJelly .. " dropped " .. gotRow(g, jellyRow))
	roll("Slime", false, nil, nil, L.Jackpot.Chance * HALF - 1e-12)
	local paid = jackpotPaid()
	roll("Slime", false, nil, nil, L.Jackpot.Chance * HALF)
	check(paid and not jackpotPaid(), "BullyStacks 3: still exactly x0.5 for the jackpot (the drop penalty does not stack)", tostring(paid))

	-- BullyStacks 0 (the same player after the last stack decayed): the normal chances, nothing halved
	setStacks(0)
	rowThresholds("BullyStacks 0", 1)
	jackpotThresholds("BullyStacks 0", 1)

	-- the first king-slime scroll is granted before the rolls: a bully still gets exactly one (no draw, nothing halved)
	local fs = fixture()
	fs.Player:SetAttribute("BullyStacks", 1)
	fs.ScriptConst, fs.Draws = 0.999999, 0
	fs:Kill("BigSlime")
	check(fs:Count("Enh70") == 1 and fs.Data.LootFlags.FirstScroll == true and fs:Noticed(L.Text.FirstScroll) == 1,
		"BullyStacks 1: the first king slime still guarantees exactly one Enh70 (flag + guide)",
		show({ fs:Count("Enh70"), fs.Data.LootFlags.FirstScroll, fs:Noticed(L.Text.FirstScroll) }))
	check(fs.Draws == #L.Tables.BigSlime - belowLevelRows(fs, "BigSlime", fs.Data.Level),
		"BullyStacks 1: the first-scroll guarantee uses no draw (one draw per row only)", fs.Draws)
	fs:Kill("BigSlime")
	check(fs:Count("Enh70") == 1 and fs:Noticed(L.Text.FirstScroll) == 1, "BullyStacks 1: the guarantee is still paid only once",
		fs:Count("Enh70"))

	-- A23-27 below Lv12: the king's T4 row is not drawn and pays its 3 BelowLevel candies (no draw, so no x0.5 either);
	-- the 8-candy row is halved like every row (P 1 x 0.5)
	t:Set("Level", 1)
	setStacks(1)
	local king = L.Tables.PumpkinKing
	t.ScriptConst, t.Draws = 0.999999, 0
	t.Data.Items, t.Data.WeaponOwnedMask = {}, 1
	local kg = t:Roll("PumpkinKing", false)
	t.ScriptConst = nil
	check(t:Gained(kg, "Item", "Candy") == 3 and t:Gained(kg, "Weapon", 4) == 0 and t.Draws == #king - 1,
		"BullyStacks 1 below Lv12: the king pays only the 3 BelowLevel candies (8-candy row halved and missed, T4 row not drawn)",
		show({ t:Gained(kg, "Item", "Candy"), t.Draws }))
	setStacks(0)
end)

------------------------------------------------------------------ 2b. debug LootRoll = count only (review B12)
runGroup("lootroll", function()
	local f = fixture()
	local L = f.L
	f:Pushes()
	local function quiet(label, fn)
		local before = f:State()
		local rows = deepCopy(f.Rows)
		f.Notices, f.FxLog, f.All, f.GoldLog, f.EnhLog, f.Announces = {}, {}, {}, {}, {}, {}
		local granted = 0
		local conn = f.Loot.ItemsGranted:Connect(function() granted += 1 end)
		local result = fn()
		conn:Disconnect()
		local _, pushes = f:LastPayload()
		check(deepEqual(before, f:State()) and deepEqual(rows, f.Rows), label .. ": no save data changed", show(f:State().Items))
		check(#f.Notices == 0 and #f.FxLog == 0 and #f.All == 0 and #f.Announces == 0 and #f.GoldLog == 0 and granted == 0 and pushes == 0,
			label .. ": no notice / Fx / announcement (NotifyAll or AnnounceService) / gold / ItemsGranted / Inventory push",
			show({ #f.Notices, #f.FxLog, #f.All, #f.Announces, #f.GoldLog, granted, pushes }))
		return result
	end
	-- every row succeeds: the tally counts everything, nothing is granted (not even the legendary or the first scroll)
	f.ScriptConst, f.Draws = 0, 0
	local tally = quiet("all rows hit", function() return f.Loot.DebugSimulate("Slime", 50, false) end)
	check(type(tally) == "table" and tally.Kills == 50, "tally.Kills = n", show(tally))
	check(tally and tally.Jelly == 50 and tally.Enh70 == 50 and tally.HP == 50 and tally.MP == 50
		and tally["Weapon" .. L.Jackpot.Tier] == 50, "tally counts every row and the jackpot", show(tally))
	check(f.Draws == 50 * (#L.Tables.Slime + 1), "one draw per row (+ jackpot) per simulated kill", f.Draws)
	check(not bit32.btest(f.Data.WeaponOwnedMask, bit32.lshift(1, L.Jackpot.Tier - 1)) and f.Data.LootFlags.FirstScroll ~= true,
		"simulated jackpot / king slime grant nothing")
	f.ScriptConst = 0
	local king = quiet("king slime", function() return f.Loot.DebugSimulate("BigSlime", 3, false) end)
	check(king and king.Jelly == 3 * 2 and king.SlimeCore == 3, "rows with N count N per drop", show(king))
	-- A23-27: DebugSimulate has no killer Level, so the Pumpkin King's BelowLevel T4 row is rolled as a normal row
	f.ScriptConst, f.Draws = 0, 0
	local pk = quiet("pumpkin king", function() return f.Loot.DebugSimulate("PumpkinKing", 4, false) end)
	check(pk and pk.Weapon4 == 4 and pk.Candy == 4 * 8 and f.Draws == 4 * #L.Tables.PumpkinKing,
		"A23-27 DebugSimulate (no Level) rolls the king's T4 row like any row (no BelowLevel candies)", show({ pk, f.Draws }))
	-- golden multiplies chances exactly like RollKill
	local jelly = rowIndex(L, "Slime", "Item", "Jelly")
	local function scripted(golden)
		local s = {}
		for i in L.Tables.Slime do s[i] = (i == jelly) and 0.5 or 0.999999 end
		table.insert(s, 0.999999)
		f.Script, f.ScriptConst = s, nil
		return quiet("golden " .. tostring(golden), function() return f.Loot.DebugSimulate("Slime", 1, golden) end)
	end
	local plain, golden = scripted(false), scripted(true)
	check(plain and (plain.Jelly or 0) == 0 and golden and golden.Jelly == 1, "golden == true uses GoldenMult (0.3 x 3 > 0.5)",
		show({ plain, golden }))
	f.Script, f.ScriptConst = {}, 0.999999
	-- bounds and bad input
	local one = quiet("n clamps low", function() return f.Loot.DebugSimulate("Slime", 0) end)
	check(one and one.Kills == 1, "n < 1 counts one kill", show(one))
	local frac = quiet("n floors", function() return f.Loot.DebugSimulate("Slime", 2.9) end)
	check(frac and frac.Kills == 2, "fractional n is floored", show(frac))
	for _, kind in { "Dragon", "", 5 } do
		check(quiet("bad kind", function() return f.Loot.DebugSimulate(kind, 10) end) == nil, "unknown monster kind returns nil", tostring(kind))
	end
end)

------------------------------------------------------------------ 2c. P7 seen monsters (the item list shows only defeated kinds' drop tables)
runGroup("seen", function()
	local f = fixture()
	local L = f.L
	f.Data.LootFlags.FirstScroll = true
	f:Set("Level", 50) -- C2: a Lv1 slime pays the tier-3 row's BelowLevel jelly (a push)
	f:Pushes()
	f.ScriptConst = 0.999999 -- nothing drops: the push below comes from the first-kill flag alone
	f:Kill("Slime")
	local p1, n1 = f:LastPayload()
	check(f.Data.LootFlags["Seen:Slime"] == true, "the first slime kill sets LootFlags[\"Seen:Slime\"]", show(f.Data.LootFlags))
	check(n1 == 1 and p1 and deepEqual(p1.Seen, { Slime = true }), "the first kill of a kind pushes the Inventory with Seen[kind], even with no drop",
		show({ n1, p1 and p1.Seen }))
	f:Kill("Slime")
	local _, n2 = f:LastPayload()
	check(n2 == 0, "a later no-drop kill of a seen kind sends no Inventory push", n2)
	for _, kind in { "Dragon", "", "slime" } do f:Roll(kind) end
	local _, n3 = f:LastPayload()
	check(n3 == 0 and f.Data.LootFlags["Seen:Dragon"] == nil and f.Data.LootFlags["Seen:"] == nil and f.Data.LootFlags["Seen:slime"] == nil,
		"kinds without a drop table are never marked seen", show(f.Data.LootFlags))
	local want = {}
	for kind in L.Tables do
		f:Kill(kind, { Auto = true })
		want[kind] = true
	end
	local pAll = f:LastPayload()
	check(pAll and deepEqual(pAll.Seen, want), "every drop-table kind killed once is listed in Seen (auto kills count)", show(pAll and pAll.Seen))
	-- the count-only debug roll never marks anything
	local d = fixture()
	d.ScriptConst = 0
	d.Loot.DebugSimulate("Goblin", 5)
	check(d.Data.LootFlags["Seen:Goblin"] == nil, "DebugSimulate never marks a kind seen", show(d.Data.LootFlags))
	-- saved, and the payload shows only real drop-table kinds flagged exactly true
	f:Release()
	local row = f.Rows["P_" .. f.UserId]
	check(row.LootFlags["Seen:Slime"] == true and row.LootFlags["Seen:SkeletonKnight"] == true, "Seen flags are in the saved record",
		show(row.LootFlags))
	local re = fixture({ Rows = f.Rows, UserId = f.UserId })
	local pr = re:LastPayload()
	check(pr and deepEqual(pr.Seen, want), "Seen survives reload (sent with the join push)", show(pr and pr.Seen))
	local saved = deepCopy(DEFAULT_ROW)
	saved.LootFlags = { ["Seen:Goblin"] = true, ["Seen:Dragon"] = true, ["Seen:Skeleton"] = "yes", ["Seen:Bad Kind"] = true,
		["Seen:"] = true, Seen = true, FirstScroll = true }
	local g = fixture({ Saved = saved })
	local pg = g:LastPayload()
	check(pg and deepEqual(pg.Seen, { Goblin = true }), "payload Seen lists only real drop-table kinds flagged true (unknown / malformed keys hidden)",
		show(pg and pg.Seen))
end)

------------------------------------------------------------------ 3. weapons
------------------------------------------------------------------ C2 the first Slime Prince's weapon
runGroup("first weapon drop", function()
	local f = fixture()
	local L = f.L
	f.Data.LootFlags.FirstScroll = true
	local fw = L.FirstWeaponDrop
	check(fw and fw.Monster == "BigSlime" and fw.Tier == 2, "Config.Loot.FirstWeaponDrop = the Slime Prince's tier 2", show(fw))
	f.ScriptConst = 0.999999 -- no row drops: the weapon is the guarantee alone
	local g = f:Roll("BigSlime")
	local name = f.Config.WeaponName(2, "Warrior", "Halo")
	check(bit32.btest(f.Data.WeaponOwnedMask, 2) and f:Gained(g, "Weapon", 2) == 1 and f.Data.LootFlags.FirstWeapon == true,
		"the first Prince kill: tier 2 owned, in the Loot list, the flag set", show({ f.Data.WeaponOwnedMask, f.Data.LootFlags }))
	check(f.Data.WeaponTier == 2 and f:Noticed(string.format(L.Text.FirstDropEquip, name)) == 1,
		"it beats the tier-1 weapon in hand: equipped at once (FirstDropEquip)", show({ f.Data.WeaponTier }))
	f.Data.WeaponOwnedMask, f.Data.WeaponTier = 1, 1
	g = f:Roll("BigSlime")
	check(f:Gained(g, "Weapon", 2) == 0 and f.Data.WeaponOwnedMask == 1, "only the first Prince: never a second guarantee", "")
	f.ScriptConst = nil
	-- owned already: the chance is used up, nothing given
	local o = fixture()
	o.Data.LootFlags.FirstScroll = true
	o:Set("WeaponOwnedMask", 3)
	o.ScriptConst = 0.999999
	g = o:Roll("BigSlime")
	check(o.Data.LootFlags.FirstWeapon == true and o:Gained(g, "Weapon", 2) == 0 and (o.Data.Spares == nil or next(o.Data.Spares) == nil),
		"tier 2 owned already: the flag is used, nothing given (no Spare)", show(o.Data.Spares))
	-- a stronger weapon in hand (tier 1 +10): owned, not equipped (FirstDropWeapon)
	local s2 = fixture()
	s2.Data.LootFlags.FirstScroll = true
	s2.Data.WeaponEnhance[1] = 10
	s2.ScriptConst = 0.999999
	s2:Roll("BigSlime")
	local t1, t2 = s2.Config.WeaponDamage(1, 1, 10), s2.Config.WeaponDamage(2, 1, 0)
	check(t1 >= t2 and s2.Data.WeaponTier == 1 and bit32.btest(s2.Data.WeaponOwnedMask, 2)
		and s2:Noticed(string.format(L.Text.FirstDropWeapon, name)) == 1, "a stronger weapon in hand stays; the line says it dropped",
		show({ t1, t2, s2.Data.WeaponTier }))
	-- bare hands: equipped
	local b = fixture()
	b.Data.LootFlags.FirstScroll = true
	b:Set("WeaponTier", 0)
	b:Set("WeaponOwnedMask", 0)
	b.ScriptConst = 0.999999
	b:Roll("BigSlime")
	check(b.Data.WeaponTier == 2, "bare hands: equipped", show(b.Data.WeaponTier))
	-- a free rider's share (Minor) and the practice King roll nothing, the flag stays unused
	local m = fixture()
	m.Data.LootFlags.FirstScroll = true
	m:Roll("BigSlime", false, { Minor = true })
	check(m.Data.LootFlags.FirstWeapon == nil and not bit32.btest(m.Data.WeaponOwnedMask, 2), "a free rider's share: no guarantee used", "")
end)

runGroup("weapons", function()
	local f = fixture()
	local L = f.L
	f.Data.LootFlags.FirstScroll = true
	local C = f.Config
	local gradesSeen = {}
	for kind, rows in L.Tables do
		for i, row in rows do
			if row.Weapon then
				local w = fixture()
				w.Data.LootFlags.FirstScroll = true
				w.Data.LootFlags.FirstWeapon = true -- C2: the first Prince's weapon is checked on its own
				local bitMask = bit32.lshift(1, row.Weapon - 1)
				if type(row.BelowLevel) == "table" then
					-- A23-27: below the weapon's MinLevel this row pays BelowLevel with no draw (one script value unused)
					local b = fixture()
					b.Data.LootFlags.FirstScroll = true
					b.Data.LootFlags.FirstWeapon = true
					local min = C.Weapons[row.Weapon].MinLevel
					b:Set("Level", min - 1)
					local bg, unused = b:Force(kind, { [i] = true })
					-- every BelowLevel weapon row of this table above the killer's level skips its draw (Captain Clatter
					-- has two: T5 and T6)
					local skipped = 0
					for _, r in rows do
						if r.Weapon and type(r.BelowLevel) == "table" and C.Weapons[r.Weapon].MinLevel > min - 1 then skipped += 1 end
					end
					check(b.Data.WeaponOwnedMask == 1 and b:Gained(bg, "Weapon", row.Weapon) == 0 and #b.Announces == 0 and #b.GoldLog == 0
						and unused == skipped, "A23-27 a BelowLevel weapon row below MinLevel grants no weapon, no announce, no draw",
						kind .. " tier " .. row.Weapon .. " Lv" .. (min - 1) .. " unused " .. unused)
					check(b:Count(row.BelowLevel.Item) >= row.BelowLevel.N, "A23-27 ... and pays its BelowLevel item instead",
						kind .. " " .. show(b.Data.Items))
					-- the drop tests below need a killer at the weapon's MinLevel
					w:Set("Level", min)
				end
				local ownedAtAnnounce = nil
				w.OnAnnounce = function(_, key) if key == "RareWeapon" then ownedAtAnnounce = bit32.btest(w.Data.WeaponOwnedMask, bitMask) end end
				local g = w:Force(kind, { [i] = true })
				check(w.Data.WeaponOwnedMask == bit32.bor(1, bitMask) and w.Player:GetAttribute("WeaponOwnedMask") == w.Data.WeaponOwnedMask,
					"unowned weapon drop sets its mask bit (saved + mirrored)", kind .. " tier " .. row.Weapon)
				check(w:Gained(g, "Weapon", row.Weapon) == 1 and #w.GoldLog == 0, "new weapon is reported once and pays no gold")
				check(w.Data.WeaponTier == 1, "a weapon drop never auto-equips")
				local name = w.Config.WeaponName(row.Weapon, "Warrior", "Halo")
				-- the personal notice names the grade (review of 0db0764: "영웅 무기! … 획득!")
				check(w:Noticed(string.format(L.Text.RareWeapon, w.Config.WeaponGrade(row.Weapon).Name, name)) == 1,
					"rare weapon notice", name)
				-- A23-15: a new Rare+ drop is announced server-wide once, with the monster kind (the client names the weapon)
				local grade = C.WeaponInfo[row.Weapon].Grade
				gradesSeen[grade] = true
				local rare = w:Announced("RareWeapon")
				if C.WeaponGrade(row.Weapon).Rank >= C.Announce.MinWeaponGrade then
					check(#rare == 1 and #w.Announces == 1, "a new Rare+ weapon drop calls AnnounceService exactly once (RareWeapon)",
						kind .. " tier " .. row.Weapon .. " " .. show(w.Announces))
					check(rare[1] ~= nil and rare[1].Player == w.Player and deepEqual(rare[1].Args, { Weapon = row.Weapon, Monster = kind })
						and rare[1].Grade == grade and rare[1].Extra == 0,
						"RareWeapon announce = (player, { Weapon = tier, Monster = kind }, the tier's grade id)", show(rare[1]))
					check(ownedAtAnnounce == true, "weapon ownership is saved before the RareWeapon announce", kind .. " tier " .. row.Weapon)
				else
					check(#w.Announces == 0, "a Common / Fine drop is never announced", kind .. " tier " .. row.Weapon)
				end
				check(#w.All == 0, "weapon drops never use Net.NotifyAll", #w.All)
				local maskBefore, carried = w.Data.WeaponOwnedMask, w.Data.CarriedGold
				g = w:Force(kind, { [i] = true })
				local gold = L.DuplicateWeaponGold[row.Weapon]
				local key = row.Weapon .. ":0"
				check(w.Data.WeaponOwnedMask == maskBefore, "duplicate weapon drop does not change the mask")
				-- C2: a weapon owned already is a Spare (+0) in the bag, no gold
				check(type(w.Data.Spares) == "table" and w.Data.Spares[key] == 1 and w.Data.CarriedGold == carried and #w.GoldLog == 0
					and w:Noticed(string.format(L.Text.SpareWeapon, name)) == 1,
					"C2 a duplicate weapon becomes a Spare (+0) with one line, no gold", show({ w.Data.Spares, w.GoldLog }))
				-- ... and only with the Spares full (60) the old DuplicateWeaponGold, through AddCarriedGold (once)
				w.Data.Spares = { ["1:0"] = 20, ["1:1"] = 20, ["1:2"] = 20 }
				g = w:Force(kind, { [i] = true })
				check(w.Data.CarriedGold == carried + gold and #w.GoldLog == 1 and w.GoldLog[1].Amount == gold and w.GoldLog[1].Source == "Loot"
					and w.Data.Spares[key] == nil, "duplicate weapon with the Spares full: DuplicateWeaponGold via ProgressionService.AddCarriedGold (once)",
					show(w.GoldLog))
				check(w:Gained(g, "Weapon", row.Weapon) == 0, "duplicate is not reported as a new weapon")
				check(#w:Announced("RareWeapon") == #rare and #w.Announces == #rare, "a duplicate weapon drop is not announced again",
					show(w.Announces))
			end
		end
	end
	check(gradesSeen.Rare == true and gradesSeen.Epic == true, "the real drop tables cover Rare and Epic weapon drops", show(gradesSeen))

	-- the grade threshold on a probe monster kind (test-only table, this fixture only): tiers 2 Common, 3 Fine, 4 Rare, 5 Epic
	local function probe(setup)
		local p = fixture()
		p.Data.LootFlags.FirstScroll = true
		p.L.Tables.AnnounceProbe = { { Weapon = 2, P = 1 }, { Weapon = 3, P = 1 }, { Weapon = 4, P = 1 }, { Weapon = 5, P = 1 } }
		if setup then setup(p) end
		local g = p:Force("AnnounceProbe", { true, true, true, true })
		local tiers, grades = {}, {}
		for _, a in p:Announced("RareWeapon") do
			table.insert(tiers, a.Args.Weapon)
			table.insert(grades, a.Grade)
			check(a.Args.Monster == "AnnounceProbe", "RareWeapon announce names the monster kind that dropped it", show(a.Args))
		end
		return p, g, tiers, grades
	end
	local p, g, tiers, grades = probe()
	check(p:Gained(g, "Weapon", 2) == 1 and p:Gained(g, "Weapon", 3) == 1 and p:Gained(g, "Weapon", 4) == 1 and p:Gained(g, "Weapon", 5) == 1,
		"probe: all four new weapons are granted", show(g))
	check(deepEqual(tiers, { 4, 5 }) and deepEqual(grades, { "Rare", "Epic" }) and #p.Announces == 2,
		"only Rare / Epic drops are announced (Common tier 2 / Fine tier 3 are not)", show({ tiers, grades }))
	for tier = 2, 5 do
		local nm = p.Config.WeaponName(tier, "Warrior", "Halo")
		check(p:Noticed(string.format(L.Text.RareWeapon, p.Config.WeaponGrade(tier).Name, nm)) == 1,
			"every new weapon still gets the personal grade notice (announced or not)", tier)
	end
	-- the rule reads the tier's grade (Config.WeaponInfo) and Config.Announce.MinWeaponGrade, not fixed tiers
	p, g, tiers, grades = probe(function(x) x.Config.WeaponInfo[2].Grade = "Epic"; x.Config.WeaponInfo[4].Grade = "Fine" end)
	check(deepEqual(tiers, { 2, 5 }) and deepEqual(grades, { "Epic", "Epic" }), "announce follows Config.WeaponInfo grades (tier 2 as Epic, tier 4 as Fine)",
		show({ tiers, grades }))
	p, g, tiers = probe(function(x) x.Config.Announce.MinWeaponGrade = 2 end)
	check(deepEqual(tiers, { 3, 4, 5 }), "the threshold is Config.Announce.MinWeaponGrade (2 = Fine and up)", show(tiers))
	p, g, tiers = probe(function(x) x.Config.Announce.MinWeaponGrade = 5 end)
	check(#tiers == 0, "MinWeaponGrade 5: Epic drops are not announced", show(tiers))

	-- jackpot: legendary tier 8, saved before any announcement, exactly one Jackpot announce (grade Legend)
	local j = fixture()
	local tierBit = bit32.lshift(1, L.Jackpot.Tier - 1)
	local ownedAtAnnounce = nil
	j.OnAnnounce = function(_, key) if key == "Jackpot" then ownedAtAnnounce = bit32.btest(j.Data.WeaponOwnedMask, tierBit) end end
	local jg = j:Force("Slime", nil, true)
	check(bit32.btest(j.Data.WeaponOwnedMask, tierBit) and j:Gained(jg, "Weapon", L.Jackpot.Tier) == 1, "jackpot grants the legendary tier")
	local jp = j:Announced("Jackpot")
	check(#jp == 1 and #j.Announces == 1, "a new jackpot legendary calls AnnounceService exactly once (Jackpot, no RareWeapon line)",
		show(j.Announces))
	check(jp[1] ~= nil and jp[1].Player == j.Player and deepEqual(jp[1].Args, { Weapon = L.Jackpot.Tier }) and jp[1].Grade == "Legend"
		and jp[1].Extra == 0, "Jackpot announce = (player, { Weapon = tier }, \"Legend\")", show(jp[1]))
	check(#j.All == 0, "the jackpot no longer uses Net.NotifyAll (AnnounceService line only)", #j.All)
	check(ownedAtAnnounce == true, "legendary ownership is saved before the announcement")
	local name = j.Config.WeaponName(L.Jackpot.Tier, "Warrior", "Halo")
	check(j:Noticed(string.format(L.Text.JackpotSelf, name)) == 1, "jackpot owner notice")
	local carried = j.Data.CarriedGold
	j:Force("Slime", nil, true)
	check(#j.Announces == 1 and #j.All == 0 and j.Data.CarriedGold == carried and j.Data.Spares[L.Jackpot.Tier .. ":0"] == 1,
		"second jackpot = a Spare (C2), no second announcement", show({ #j.Announces, #j.All, j.Data.Spares }))
	local jg2 = fixture()
	jg2:Force("Slime", nil, true, true, { Auto = true })
	check(#jg2:Announced("Jackpot") == 1 and deepEqual(jg2.Announces[1].Args, { Weapon = L.Jackpot.Tier }),
		"a golden / auto-kill jackpot is announced the same way", show(jg2.Announces))
	local m = fixture()
	m:Set("Class", "Mage")
	m:Force("Slime", nil, true)
	local mj = m:Announced("Jackpot")
	check(m:Noticed(string.format(L.Text.JackpotSelf, m.Config.WeaponName(8, "Mage", "Halo"))) == 1 and #mj == 1
		and deepEqual(mj[1].Args, { Weapon = 8 }),
		"jackpot: the owner's notice names the class weapon; the announce carries the tier (each client names it)", show(mj))

	-- the announcement never blocks or breaks the grant: AnnounceService missing, or raising inside Announce
	local na = fixture()
	na.Registry.AnnounceService = nil
	na.FxLog = {}
	local okMissing, gMissing = pcall(function() return na:Force("Slime", nil, true) end)
	check(okMissing and bit32.btest(na.Data.WeaponOwnedMask, tierBit) and na:Gained(gMissing, "Weapon", L.Jackpot.Tier) == 1
		and na.FxLog[1] ~= nil and na.FxLog[1].Kind == "Loot", "without AnnounceService the jackpot is still granted (announce skipped)",
		tostring(gMissing))
	local thr = fixture()
	thr.Data.LootFlags.FirstScroll = true
	thr.AnnounceThrows = true
	thr.FxLog = {}
	local okThrow, gThrow = pcall(function() return thr:Force("Slime", nil, true) end)
	check(okThrow and bit32.btest(thr.Data.WeaponOwnedMask, tierBit) and thr:Gained(gThrow, "Weapon", L.Jackpot.Tier) == 1
		and thr.FxLog[1] ~= nil and thr.FxLog[1].Kind == "Loot" and #thr:Announced("Jackpot") == 1,
		"an error inside AnnounceService.Announce never breaks the jackpot grant (pcall)", tostring(gThrow))
	local goblinWeapon = rowIndex(L, "Goblin", "Weapon", 4)
	local okRare, gRare = pcall(function() return thr:Force("Goblin", { [goblinWeapon] = true }) end)
	check(okRare and bit32.btest(thr.Data.WeaponOwnedMask, 8) and thr:Gained(gRare, "Weapon", 4) == 1 and #thr:Announced("RareWeapon") == 1,
		"an error inside AnnounceService.Announce never breaks a rare weapon grant (pcall)", tostring(gRare))
end)

------------------------------------------------------------------ 4. UseItem: enhance scrolls
runGroup("enhance", function()
	local f = fixture()
	local L = f.L
	-- statistics: 12,000 seeded uses per scroll type through the real remote
	for _, id in { "Enh70", "Enh30", "Enh10" } do
		local def = L.Items[id]
		math.randomseed(#id * 7919 + def.Plus)
		local nUses = math.floor(12000 * SAMPLE_SCALE)
		local succ, failsPos, drops, consumedBad, wrong, outOfRange, refused, attrBad = 0, 0, 0, 0, 0, 0, 0, 0
		for i = 1, nUses do
			local start = (i - 1) % 10
			f.Data.WeaponEnhance[1] = start
			if f:Count(id) < 2 then f:Give(id, 900) end
			local have = f:Count(id)
			f.EnhLog, f.Notices, f.FxLog = {}, {}, {}
			f:Use(id, 1)
			local ev = f.EnhLog[1]
			local after = f:Enh(1)
			if not ev then
				refused += 1
			else
				if have - f:Count(id) ~= 1 then consumedBad += 1 end
				if ev.Before ~= start or ev.After ~= after then wrong += 1 end
				if ev.Success then
					succ += 1
					if after ~= math.min(L.MaxEnhance, start + def.Plus) then wrong += 1 end
				elseif start > 0 then
					failsPos += 1
					if after == start - 1 then drops += 1 elseif after ~= start then wrong += 1 end
				elseif after ~= 0 then
					wrong += 1
				end
			end
			if after < 0 or after > L.MaxEnhance or after ~= math.floor(after) then outOfRange += 1 end
			if f.Player:GetAttribute("WeaponEnhance") ~= after then attrBad += 1 end
		end
		stat(id .. ".success", succ, nUses, def.Chance)
		stat(id .. ".failDrop", drops, failsPos, L.FailDropChance)
		check(refused == 0, "every valid use is accepted", id .. " refused " .. refused)
		check(within(succ, nUses, def.Chance), "enhance success rate ~ Chance", id .. " " .. succ .. "/" .. nUses)
		check(within(drops, failsPos, L.FailDropChance), "a failure from >+0 drops one level ~50%", id .. " " .. drops .. "/" .. failsPos)
		check(consumedBad == 0, "exactly one scroll consumed per accepted use", id .. " " .. consumedBad)
		check(wrong == 0, "success = +Plus capped at 10; failure = -1 or unchanged, +0 stays +0", id .. " " .. wrong)
		check(outOfRange == 0, "enhancement never below +0 or above +10", id .. " " .. outOfRange)
		check(attrBad == 0, "WeaponEnhance attribute follows the equipped tier", id .. " " .. attrBad)
	end
	-- cap: +9 with any scroll success -> exactly +10
	for _, id in { "Enh70", "Enh30", "Enh10" } do
		f.Data.WeaponEnhance[1] = 9
		f:Give(id, 1)
		f.Script = { 0 }
		f:Use(id, 1)
		f.Script = {}
		check(f:Enh(1) == 10, "+9 success caps at +10", id .. " -> " .. tostring(f:Enh(1)))
	end
	-- refused at +10 without consuming
	for _, id in { "Enh70", "Enh30", "Enh10" } do
		f.Data.WeaponEnhance[1] = 10
		f:Give(id, 3)
		local have = f:Count(id)
		f.Draws, f.Notices = 0, {}
		f:Use(id, 1)
		check(f:Count(id) == have and f:Enh(1) == 10 and f.Draws == 0, "at +10 the scroll is refused and kept", id)
		check(f:Noticed(string.format(L.Text.EnhanceMax, L.MaxEnhance)) == 1, "EnhanceMax notice at +10", id)
	end
	-- precise failure paths
	f.Data.WeaponEnhance[1] = 5
	f:Give("Enh70", 2)
	f.Script, f.Notices = { 0.95, 0.1 }, {} -- fail, then drop
	f:Use("Enh70", 1)
	check(f:Enh(1) == 4, "failed scroll with drop roll < 0.5 loses exactly one level", f:Enh(1))
	-- 게임성 검수 10/12 (A23-99: a loss is always said): the result toasts stay - the Bag window draws no result line
	local wname = f.Config.WeaponName(1, "Warrior", "Halo")
	local downLine = string.format(L.Text.EnhanceFailDown, wname, 5, 4)
	local downKind = nil
	for _, e in f.Notices do if e.Text == downLine then downKind = e.Kind end end
	check(f:Noticed(downLine) == 1 and downKind == "bad", "a drop says '+5 → +4' in red (kind bad)", show({ f.Notices[1] and f.Notices[1].Text, downKind }))
	f.Script, f.Notices = { 0.95, 0.6 }, {} -- fail, keep
	f:Use("Enh70", 1)
	check(f:Enh(1) == 4, "failed scroll with drop roll >= 0.5 keeps the level", f:Enh(1))
	check(f:Noticed(string.format(L.Text.EnhanceFailKeep, wname, 4)) == 1, "a kept level says 'stays +4'",
		show({ f.Notices[1] and f.Notices[1].Text }))
	f.Script, f.Notices = { 0 }, {} -- success
	f:Give("Enh70", 1)
	f:Use("Enh70", 1)
	check(f:Enh(1) == 4 + L.Items.Enh70.Plus and f:Noticed(string.format(L.Text.EnhanceOk, wname, 4, f:Enh(1))) == 1,
		"a success says '+4 → +N!'", show({ f.Notices[1] and f.Notices[1].Text }))
	f.Script = {}
	f.Data.WeaponEnhance[1] = 0
	f:Give("Enh10", 1)
	f.Script, f.Draws = { 0.95 }, 0
	f:Use("Enh10", 1)
	check(f:Enh(1) == 0 and f.Draws == 1, "failure at +0 stays +0 without a drop roll", f.Draws)
	f.Script = {}
	-- exact gains (A23-14: +1 / +3 / +5) and the overflow cap at +10
	for _, case in { { "Enh70", 0, 1 }, { "Enh30", 2, 5 }, { "Enh10", 0, 5 }, { "Enh10", 4, 9 }, { "Enh10", 8, 10 }, { "Enh30", 9, 10 } } do
		f.Data.WeaponEnhance[1] = case[2]
		f:Give(case[1], 1)
		f.Script = { 0 }
		f:Use(case[1], 1)
		f.Script = {}
		check(f:Enh(1) == case[3], "success adds exactly Plus (+1/+3/+5), capped at +10", show(case) .. " -> " .. tostring(f:Enh(1)))
	end

	-- refused cases keep everything
	local r = fixture()
	r:Give("Enh70", 3)
	local function refusedCase(label, fn, notice)
		local before = r:State()
		r.Draws, r.Notices, r.EnhLog = 0, {}, {}
		fn()
		check(deepEqual(before, r:State()) and r.Draws == 0 and #r.EnhLog == 0, label, show(r:State().Items))
		if notice then check(r:Noticed(notice) == 1, label .. " (notice)") end
	end
	refusedCase("unowned tier refused, scroll kept", function() r:Use("Enh70", 5) end, r.L.Text.NotOwned)
	refusedCase("missing scroll refused", function() r:Use("Enh30", 1) end, r.L.Text.NoItem)
	for _, bad in { "1", 1.5, 0, 9, -1, 0 / 0, math.huge, {}, true } do
		refusedCase("bad tier argument refused (non-number / fractional / out of range)", function() r:Use("Enh70", bad) end)
	end
	refusedCase("missing tier argument refused", function() r:Use("Enh70") end)
	refusedCase("extra argument refused (Enh70, 1, 2)", function() r:Use("Enh70", 1, 2) end)
	refusedCase("extra argument refused (Enh70, 1, 'x')", function() r:Use("Enh70", 1, "x") end)
	do
		local x = fixture()
		x:Give("Enh70", 3)
		local before = x:State()
		x.Draws = 0
		x:Use("Enh70", 1, nil, 5)
		check(deepEqual(before, x:State()) and x.Draws == 0, "trailing extra argument refused (Enh70, 1, nil, 5)", show(x:State().Items))
	end
	refusedCase("unknown item id refused", function() r:Use("Bogus", 1) end)
	refusedCase("non-string item id refused", function() r:Use(5, 1) end)
	-- review B6: no scroll during PvP combat (the scroll is kept, no roll)
	r.InCombat = true
	refusedCase("enhance refused while CombatService.IsInCombat, scroll kept", function() r:Use("Enh70", 1) end, r.L.Text.UseCombat)
	r.InCombat = false
	r.Now += 5
	r:Give("Jelly", 2)
	refusedCase("material item cannot be used", function() r:Use("Jelly", 1) end)
	r.Ready = false
	refusedCase("not-ready player refused", function() r:Use("Enh70", 1) end)
	r.Ready = true
	r.Player.Parent = nil
	refusedCase("player that left refused", function() r:Use("Enh70", 1) end)
	r.Player.Parent = r.World.Players
	-- rate limit: UseItem = Config.RateLimits.UseItem
	r.Now += 5
	local have = r:Count("Enh70")
	r.ScriptConst = 0.999
	r:FireRaw("UseItem", "Enh70", 1)
	r:FireRaw("UseItem", "Enh70", 1)
	check(r:Count("Enh70") == have - 1, "UseItem rate limited (second call in the window ignored)", r:Count("Enh70"))
	r.Now += r.Config.RateLimits.UseItem - 0.01
	r:FireRaw("UseItem", "Enh70", 1)
	check(r:Count("Enh70") == have - 1, "UseItem still limited just before the window ends")
	r.Now += 0.02
	r:FireRaw("UseItem", "Enh70", 1)
	check(r:Count("Enh70") == have - 2, "UseItem accepted after the window")
	-- enhancing another owned tier never changes the equipped attribute
	local o = fixture()
	o:Set("WeaponOwnedMask", 3)
	o.Data.WeaponEnhance[1] = 3
	o:Set("WeaponTier", 2)
	o:Set("WeaponTier", 1)
	o:Give("Enh70", 1)
	o.Script = { 0 }
	o:Use("Enh70", 2)
	o.Script = {}
	check(o:Enh(2) == 1 and o.Player:GetAttribute("WeaponEnhance") == 3, "enhancing a non-equipped tier keeps the equipped +N attribute")
	check(o.Active >= 1, "an accepted use marks the player active")
end)

------------------------------------------------------------------ 5. UseItem: transfer scrolls (2026-10-05 rule: add up to +10)
runGroup("transfer", function()
	local f = fixture()
	local L = f.L
	f:Set("WeaponOwnedMask", 3)
	for _, id in { "Move70", "Move30", "Move10" } do
		local def = L.Items[id]
		math.randomseed(#id * 104729 + math.floor(def.Chance * 100))
		local nUses = math.floor(10000 * SAMPLE_SCALE)
		local succ, consumedBad, wrong, lost, refused = 0, 0, 0, 0, 0
		for i = 1, nUses do
			local from, to = 1 + (i % 10), (i * 7) % 10
			f.Data.WeaponEnhance[1], f.Data.WeaponEnhance[2] = from, to
			if f:Count(id) < 2 then f:Give(id, 900) end
			local have = f:Count(id)
			f.FxLog, f.Notices = {}, {}
			f:Use(id, 1, 2)
			local fx = f.FxLog[#f.FxLog]
			local a, b = f:Enh(1), f:Enh(2)
			if not (fx and fx.Kind == "Enhance" and fx.Data.Move == true) then
				refused += 1
			else
				if have - f:Count(id) ~= 1 then consumedBad += 1 end
				if a + b ~= from + to then lost += 1 end
				if fx.Data.Success then
					succ += 1
					local newTo = math.min(L.MaxEnhance, to + from)
					if b ~= newTo or a ~= from - (newTo - to) then wrong += 1 end
				elseif a ~= from or b ~= to then
					wrong += 1
				end
			end
		end
		stat(id .. ".success", succ, nUses, def.Chance)
		check(refused == 0, "every valid transfer is accepted", id .. " refused " .. refused)
		check(within(succ, nUses, def.Chance), "transfer success rate ~ Chance", id .. " " .. succ .. "/" .. nUses)
		check(consumedBad == 0, "exactly one transfer scroll consumed per accepted use", id)
		check(lost == 0, "no enhancement is ever lost (source + target sum unchanged)", id .. " " .. lost)
		check(wrong == 0, "success adds the source +N onto the target up to +10, overflow stays; failure changes nothing", id .. " " .. wrong)
	end
	-- exact cases
	local function move(fromN, toN, roll)
		f.Data.WeaponEnhance[1], f.Data.WeaponEnhance[2] = fromN, toN
		f:Give("Move70", 1)
		f.Script = { roll }
		f:Use("Move70", 1, 2)
		f.Script = {}
		return f:Enh(1), f:Enh(2)
	end
	local a, b = move(3, 4, 0)
	check(a == 0 and b == 7, "success +3 onto +4 -> source +0, target +7", show({ a, b }))
	a, b = move(6, 7, 0)
	check(a == 3 and b == 10, "success +6 onto +7 -> target +10, the 3 that do not fit stay on the source", show({ a, b }))
	a, b = move(5, 0, 0)
	check(a == 0 and b == 5, "success onto +0 moves everything", show({ a, b }))
	a, b = move(10, 9, 0)
	check(a == 9 and b == 10, "success +10 onto +9 -> +9 / +10", show({ a, b }))
	local have = f:Count("Move70")
	a, b = move(4, 2, 0.95)
	check(a == 4 and b == 2 and f:Count("Move70") == have, "failure leaves both, consumes the scroll (1 given, 1 used)", show({ a, b }))
	check(f:Noticed(string.format(L.Text.MoveFail, f.Config.WeaponName(1, "Warrior", "Halo"), 4)) == 1,
		"MoveFail toast (게임성 검수 10/12: the Bag window draws no result line, so the server says it)")
	-- equipped attribute follows when the equipped tier is the source or the target
	f:Set("WeaponTier", 2)
	a, b = move(4, 3, 0)
	check(f.Player:GetAttribute("WeaponEnhance") == 7, "equipped target: attribute follows the new +N", f.Player:GetAttribute("WeaponEnhance"))
	f:Set("WeaponTier", 1)
	a, b = move(8, 5, 0)
	check(f.Player:GetAttribute("WeaponEnhance") == 3, "equipped source: attribute shows the remaining +N", f.Player:GetAttribute("WeaponEnhance"))

	-- refused cases (scroll kept, nothing changes, no roll)
	local r = fixture()
	r:Set("WeaponOwnedMask", 1 + 2 + 4)
	r:Give("Move70", 3)
	local function refusedCase(label, setup, fn, notice)
		r.Data.WeaponEnhance[1], r.Data.WeaponEnhance[2], r.Data.WeaponEnhance[3] = 4, 2, 0
		if setup then setup() end
		local before = r:State()
		r.Draws, r.Notices, r.FxLog = 0, {}, {}
		fn()
		check(deepEqual(before, r:State()) and r.Draws == 0, label, show(r:State().Enh))
		if notice then check(r:Noticed(notice) == 1, label .. " (notice)") end
	end
	refusedCase("target already +10: refused, scroll kept", function() r.Data.WeaponEnhance[2] = 10 end,
		function() r:Use("Move70", 1, 2) end, string.format(r.L.Text.EnhanceMax, r.L.MaxEnhance))
	refusedCase("source +0: refused, scroll kept", nil, function() r:Use("Move70", 3, 1) end, r.L.Text.MoveNothing)
	refusedCase("from == to: refused, scroll kept", nil, function() r:Use("Move70", 1, 1) end, r.L.Text.MoveSame)
	refusedCase("unowned target: refused", nil, function() r:Use("Move70", 1, 5) end, r.L.Text.NotOwned)
	refusedCase("unowned source: refused", function() r.Data.WeaponEnhance[6] = 5 end, function() r:Use("Move70", 6, 1) end, r.L.Text.NotOwned)
	r.Data.WeaponEnhance[6] = 0
	refusedCase("missing transfer scroll: refused", nil, function() r:Use("Move30", 1, 2) end, r.L.Text.NoItem)
	refusedCase("transfer refused while in PvP combat, scroll kept", function() r.InCombat = true end,
		function() r:Use("Move70", 1, 2) end, r.L.Text.UseCombat)
	r.InCombat = false
	for _, args in { { 1 }, { 1, nil }, { "1", 2 }, { 1, 2.5 }, { 1, 9 }, { 0, 2 }, { 1, 0 / 0 }, { {}, 2 } } do
		refusedCase("bad transfer arguments refused", nil, function() r:Use("Move70", args[1], args[2]) end)
	end
	do
		local x = fixture()
		x:Set("WeaponOwnedMask", 3)
		x:Give("Move70", 3)
		x.Data.WeaponEnhance[1] = 4
		local before = x:State()
		x.Draws = 0
		x:Use("Move70", 1, 2, 3)
		check(deepEqual(before, x:State()) and x.Draws == 0, "trailing extra argument refused (Move70, 1, 2, 3)", show(x:State().Enh))
	end
	-- rate limit
	r.Data.WeaponEnhance[1], r.Data.WeaponEnhance[2] = 4, 2
	local before = r:Count("Move70")
	r.ScriptConst = 0.999
	r.Now += 5
	r:FireRaw("UseItem", "Move70", 1, 2)
	r:FireRaw("UseItem", "Move70", 1, 2)
	check(r:Count("Move70") == before - 1, "transfer rate limited")
end)

------------------------------------------------------------------ 5b. first +10 announcement (A23-15 FirstMax, once per player)
runGroup("firstmax", function()
	local f = fixture()
	local C = f.Config
	f:Set("WeaponOwnedMask", 1 + 2 + 4 + 128) -- tiers 1, 2, 3, 8
	-- what the save looks like at the moment of the announcement
	local atAnnounce = nil
	local function watch(x)
		x.OnAnnounce = function(_, key, args)
			if key == "FirstMax" then atAnnounce = { Flag = x.Data.LootFlags.FirstMax, Enh = x:Enh(args.Weapon) } end
		end
	end
	watch(f)
	local function enhance(x, tier, start, id, script)
		x.Data.WeaponEnhance[tier] = start
		x:Give(id, 1)
		x.Script = script
		x:Use(id, tier)
		x.Script = {}
		return x:Enh(tier)
	end
	check(enhance(f, 1, 3, "Enh30", { 0 }) == 6 and #f.Announces == 0 and f.Data.LootFlags.FirstMax == nil,
		"a success below +10 is not announced and sets no flag", show(f.Announces))
	check(enhance(f, 1, 9, "Enh70", { 0.95, 0.9 }) == 9 and #f.Announces == 0 and f.Data.LootFlags.FirstMax == nil,
		"a failure at +9 is not announced", show(f.Announces))
	-- the first weapon to reach +10
	check(enhance(f, 1, 9, "Enh70", { 0 }) == 10, "+9 -> +10 with an enhance scroll", f:Enh(1))
	local fm = f:Announced("FirstMax")
	check(#fm == 1 and #f.Announces == 1, "the first +10 (enhance scroll) calls AnnounceService exactly once (FirstMax)", show(f.Announces))
	check(fm[1] ~= nil and fm[1].Player == f.Player and deepEqual(fm[1].Args, { Weapon = 1 }) and fm[1].Grade == C.WeaponInfo[1].Grade
		and fm[1].Extra == 0, "FirstMax announce = (player, { Weapon = tier }, that tier's grade id)", show(fm[1]))
	check(f.Data.LootFlags.FirstMax == true and atAnnounce and atAnnounce.Flag == true and atAnnounce.Enh == 10,
		"LootFlags.FirstMax and the +10 are saved before the announcement", show(atAnnounce))
	-- once per player: a second weapon (overflow +8 + 5 capped at +10), the same weapon again, a legendary
	check(enhance(f, 2, 8, "Enh10", { 0 }) == 10 and #f:Announced("FirstMax") == 1,
		"a second weapon reaching +10 is not announced again (once per player)", show(f.Announces))
	check(enhance(f, 1, 9, "Enh30", { 0 }) == 10 and #f:Announced("FirstMax") == 1,
		"the same weapon reaching +10 again is not announced", show(f.Announces))
	check(enhance(f, 8, 7, "Enh30", { 0 }) == 10 and #f:Announced("FirstMax") == 1 and #f.Announces == 1,
		"a later legendary +10 is not announced either", show(f.Announces))
	-- a transfer reaching +10 after the first max: nothing
	f.Data.WeaponEnhance[2], f.Data.WeaponEnhance[3] = 4, 6
	f:Give("Move70", 1)
	f.Script = { 0 }
	f:Use("Move70", 2, 3)
	f.Script = {}
	check(f:Enh(3) == 10 and #f.Announces == 1, "a transfer reaching +10 after the first max is not announced", show(f.Announces))
	-- the flag is saved and survives a reload
	f:Release()
	check(f.Rows["P_" .. f.UserId].LootFlags.FirstMax == true, "LootFlags.FirstMax is in the saved record", show(f.Rows["P_" .. f.UserId].LootFlags))
	local re = fixture({ Rows = f.Rows, UserId = f.UserId })
	check(re.Data.LootFlags.FirstMax == true, "LootFlags.FirstMax survives reload (sanitize keeps it)", show(re.Data.LootFlags))
	check(enhance(re, 3, 9, "Enh70", { 0 }) == 10 and #re.Announces == 0, "no FirstMax after reload when it was already announced",
		show(re.Announces))
	-- a save that already has the flag (announced in an earlier session)
	local saved = deepCopy(DEFAULT_ROW)
	saved.LootFlags = { FirstMax = true }
	local pre = fixture({ Saved = saved })
	check(enhance(pre, 1, 9, "Enh70", { 0 }) == 10 and #pre.Announces == 0, "a saved FirstMax flag blocks the announcement", show(pre.Announces))

	-- transfer path on a fresh player: the TARGET tier is announced when it reaches +10 first
	local t = fixture()
	t:Set("WeaponOwnedMask", 1 + 2)
	watch(t)
	local function move(fromN, toN, roll)
		t.Data.WeaponEnhance[1], t.Data.WeaponEnhance[2] = fromN, toN
		t:Give("Move70", 1)
		t.Script = { roll }
		t:Use("Move70", 1, 2)
		t.Script = {}
		return t:Enh(1), t:Enh(2)
	end
	local a, b = move(6, 7, 0.95)
	check(a == 6 and b == 7 and #t.Announces == 0 and t.Data.LootFlags.FirstMax == nil, "a failed transfer is not announced", show(t.Announces))
	a, b = move(2, 3, 0)
	check(a == 0 and b == 5 and #t.Announces == 0, "a transfer below +10 is not announced", show(t.Announces))
	atAnnounce = nil
	a, b = move(6, 7, 0)
	local tm = t:Announced("FirstMax")
	check(a == 3 and b == 10 and #tm == 1 and #t.Announces == 1, "the first +10 reached by a transfer scroll is announced once (FirstMax)",
		show({ a, b, t.Announces }))
	check(tm[1] ~= nil and tm[1].Player == t.Player and deepEqual(tm[1].Args, { Weapon = 2 }) and tm[1].Grade == C.WeaponInfo[2].Grade,
		"transfer FirstMax names the target tier with its grade", show(tm[1]))
	check(t.Data.LootFlags.FirstMax == true and atAnnounce and atAnnounce.Flag == true and atAnnounce.Enh == 10,
		"transfer: LootFlags.FirstMax and the target +10 are saved before the announcement", show(atAnnounce))
	a, b = move(5, 5, 0)
	check(b == 10 and #t:Announced("FirstMax") == 1, "a second transfer +10 is not announced", show(t.Announces))
	-- after a transfer max, an enhance-scroll max is not announced either
	check(enhance(t, 1, 9, "Enh70", { 0 }) == 10 and #t.Announces == 1, "one FirstMax per player across enhance and transfer", show(t.Announces))
	-- missing / failing AnnounceService: the +10 and the flag still happen
	local na = fixture()
	na.Registry.AnnounceService = nil
	local okMissing = pcall(enhance, na, 1, 9, "Enh70", { 0 })
	check(okMissing and na:Enh(1) == 10 and na.Data.LootFlags.FirstMax == true and #na.EnhLog == 1,
		"without AnnounceService the +10 still lands (flag set, Enhanced fired)", show(na.Data.LootFlags))
	local thr = fixture()
	thr.AnnounceThrows = true
	local okThrow = pcall(enhance, thr, 1, 9, "Enh70", { 0 })
	check(okThrow and thr:Enh(1) == 10 and thr.Data.LootFlags.FirstMax == true and #thr.EnhLog == 1 and #thr:Announced("FirstMax") == 1,
		"an error inside AnnounceService.Announce never breaks the enhancement (pcall)", show(thr.Data.LootFlags))
end)

------------------------------------------------------------------ 6. EquipWeapon
runGroup("equip", function()
	local f = fixture()
	local L, C = f.L, f.Config
	f:Set("WeaponOwnedMask", 1 + 4 + 64 + 128) -- tiers 1, 3, 7, 8
	f.Data.WeaponEnhance[1], f.Data.WeaponEnhance[3], f.Data.WeaponEnhance[7], f.Data.WeaponEnhance[8] = 1, 4, 2, 7
	local function refusedCase(label, fn, notice)
		local before = f:State()
		f.Notices = {}
		local active = f.Active
		fn()
		check(deepEqual(before, f:State()) and f.Active == active, label, show({ f.Data.WeaponTier }))
		if notice then check(f:Noticed(notice) == 1, label .. " (notice)") end
	end
	refusedCase("unowned tier refused", function() f:Equip(2) end, L.Text.NotOwned)
	-- A23-28 (user 2026-10-06, replaces the A23-14 "owned weapons re-equip at any level" rule): equipping needs
	-- Level >= MinLevel, an OWNED weapon too (owning and enhancing have no level limit; the legendary T8 has MinLevel 1)
	check(f.Data.Level == 1 and C.Weapons[3].MinLevel == 5 and C.Weapons[7].MinLevel == 40 and C.Weapons[8].MinLevel == 1,
		"fixture: Lv1; tier 3 needs Lv5, tier 7 Lv40, the legendary Lv1", show({ f.Data.Level, C.Weapons[3].MinLevel, C.Weapons[7].MinLevel }))
	local needT3 = string.format(C.Text.EquipNeedLevel, C.Weapons[3].MinLevel)
	refusedCase("A23-28 an owned tier below its MinLevel is refused (tier 3 at Lv1, WeaponTier unchanged)", function() f:Equip(3) end, needT3)
	local refusal = nil
	for _, e in f.Notices do if e.Text == needT3 then refusal = e end end
	check(refusal and refusal.Kind == "bad" and f:Noticed(string.format(C.Text.WeaponNeedLevel, C.Weapons[3].MinLevel)) == 0,
		"A23-28 the refusal is Config.Text.EquipNeedLevel (kind bad), never the purchase text WeaponNeedLevel", show(refusal))
	refusedCase("A23-28 tier 7 at Lv1 is refused by its MinLevel 40 (before the faction check)", function() f:Equip(7) end,
		string.format(C.Text.EquipNeedLevel, 40))
	f:Set("Level", 4)
	refusedCase("A23-28 tier 3 at Lv4 (MinLevel - 1) is still refused", function() f:Equip(3) end, needT3)
	f:Set("Level", 1)
	f.Notices = {}
	f:Equip(8)
	check(f.Data.WeaponTier == 8 and f.Player:GetAttribute("WeaponTier") == 8 and f.Player:GetAttribute("WeaponEnhance") == 7,
		"A23-28 the legendary tier 8 (MinLevel 1) equips at Lv1 with its +N", show({ f.Data.WeaponTier, f.Player:GetAttribute("WeaponEnhance") }))
	f:Set("Level", 5)
	f.Notices = {}
	f:Equip(3)
	check(f.Data.WeaponTier == 3 and f.Player:GetAttribute("WeaponTier") == 3, "A23-28 an owned tier equips at exactly its MinLevel (tier 3 at Lv5, saved + mirrored)",
		f.Data.WeaponTier)
	check(f:Noticed(needT3) == 0, "no level refusal once the level is reached")
	check(f.Player:GetAttribute("WeaponEnhance") == 4, "WeaponEnhance attribute follows the equipped tier's +N", f.Player:GetAttribute("WeaponEnhance"))
	check(f:Noticed(string.format(L.Text.Equip, C.WeaponName(3, "Warrior", "Halo"))) == 0,
		"no equip toast (A23-130: the Bag row and the model show it; Fx Upgrade plays the Equip sound)")
	-- review B6: equip needs a living character (same as the blacksmith path)
	f.Dead = true
	refusedCase("refused while dead (Util.IsAlive)", function() f:Equip(1) end, L.Text.EquipDead)
	f.Dead = false
	f:Equip(8)
	check(f.Data.WeaponTier == 8 and f.Player:GetAttribute("WeaponEnhance") == 7, "legendary tier 8 equips with its +N")
	f:Set("Level", 40)
	f:Set("Faction", "None")
	refusedCase("RequiresFaction (tier 7) needs a faction", function() f:Equip(7) end, C.Text.NeedFaction)
	f:Set("Faction", "Halo")
	f:Equip(7)
	check(f.Data.WeaponTier == 7 and f.Player:GetAttribute("WeaponEnhance") == 2, "tier 7 equips with a faction at Lv40")
	f.InCombat = true
	refusedCase("refused while CombatService.IsInCombat", function() f:Equip(1) end, L.Text.EquipCombat)
	f.InCombat = false
	f:Set("ClassChosen", false)
	refusedCase("refused before the class is chosen", function() f:Equip(1) end)
	f:Set("ClassChosen", true)
	refusedCase("equipping the equipped tier is a no-op", function() f:Equip(7) end)
	for _, bad in { "1", 1.5, 0, 9, -1, 0 / 0, math.huge, {}, true } do
		refusedCase("bad tier argument refused", function() f:Equip(bad) end)
	end
	refusedCase("missing tier refused", function() f:Equip() end)
	do
		local x = fixture()
		x:Set("WeaponOwnedMask", 1 + 128)
		x:Set("WeaponTier", 8)
		local before = x:State()
		x:Equip(1, "x")
		check(deepEqual(before, x:State()), "trailing extra argument refused (1, 'x')", show({ x.Data.WeaponTier }))
	end
	f.Ready = false
	refusedCase("not-ready player refused", function() f:Equip(1) end)
	f.Ready = true
	f:Set("WeaponTier", 3)
	f.Now += 5
	f:FireRaw("EquipWeapon", 1)
	f:FireRaw("EquipWeapon", 8)
	check(f.Data.WeaponTier == 1, "EquipWeapon rate limited", f.Data.WeaponTier)
	check(f.Player:GetAttribute("WeaponEnhance") == 1, "attribute back to tier 1's +N")
	-- any other WeaponTier writer (shop buy / rebirth) also refreshes the attribute
	f:Set("WeaponTier", 8)
	check(f.Player:GetAttribute("WeaponEnhance") == 7, "WeaponEnhance attribute follows a WeaponTier change from another service")
end)

------------------------------------------------------------------ 6a. ShopService weapon buy / re-equip (A23-28 level gate)
-- The real ShopService onUpgradeWeapon (extracted with finite / notifyBad) on the loot fixture's save: an OWNED weapon
-- below its MinLevel -> notifyBad "EquipNeedLevel"; buying below MinLevel -> "WeaponNeedLevel" (same rule as EquipWeapon).
runGroup("shop", function()
	local f = fixture()
	local C = f.Config
	f:Set("CarriedGold", 5000)
	local function attempt(tier)
		f.Notices = {}
		local gold = f.Data.CarriedGold + f.Data.BankGold
		f:ShopBuy(tier)
		return gold - (f.Data.CarriedGold + f.Data.BankGold)
	end
	local needEquip = string.format(C.Text.EquipNeedLevel, C.Weapons[3].MinLevel)
	local needBuy = string.format(C.Text.WeaponNeedLevel, C.Weapons[3].MinLevel)
	-- an owned tier 3 (kept through a rebirth / free class change) at Lv1
	f:Set("WeaponOwnedMask", tierMask(1, 3))
	local spent = attempt(3)
	check(f.Data.WeaponTier == 1 and f.Player:GetAttribute("WeaponTier") == 1 and spent == 0 and f.Data.WeaponOwnedMask == tierMask(1, 3),
		"A23-28 shop: an owned weapon below its MinLevel is not equipped (tier 3 at Lv1, no gold)", show({ f.Data.WeaponTier, spent }))
	local bad = nil
	for _, e in f.Notices do if e.Text == needEquip then bad = e end end
	check(bad and bad.Kind == "bad" and f:Noticed(needBuy) == 0,
		"A23-28 shop: owned re-equip below MinLevel -> notifyBad EquipNeedLevel (not the purchase text)", show(f.Notices))
	f:Set("Level", 4)
	attempt(3)
	check(f.Data.WeaponTier == 1 and f:Noticed(needEquip) == 1, "A23-28 shop: owned tier 3 at Lv4 (MinLevel - 1) still refused", f.Data.WeaponTier)
	-- an unowned tier 3 below its MinLevel: the purchase text, nothing bought
	f:Set("Level", 1)
	f:Set("WeaponOwnedMask", 1)
	spent = attempt(3)
	check(f.Data.WeaponOwnedMask == 1 and f.Data.WeaponTier == 1 and spent == 0 and f:Noticed(needBuy) == 1 and f:Noticed(needEquip) == 0,
		"shop: buying below MinLevel -> WeaponNeedLevel, nothing bought", show({ f.Data.WeaponOwnedMask, spent }))
	-- at the MinLevel the owned weapon equips for free, an unowned one is bought
	f:Set("WeaponOwnedMask", tierMask(1, 3))
	f:Set("Level", 5)
	spent = attempt(3)
	check(f.Data.WeaponTier == 3 and f.Player:GetAttribute("WeaponTier") == 3 and spent == 0
		and f:Noticed(string.format(C.Loot.Text.Equip, C.WeaponName(3, "Warrior", "Halo"))) == 0,
		"A23-28 shop: the owned tier 3 equips at Lv5 for free (A23-130: no equip line, the Equip sound only)",
		show({ f.Data.WeaponTier, spent }))
	spent = attempt(2)
	check(f.Data.WeaponTier == 2 and spent == C.Weapons[2].Price and bit32.btest(f.Data.WeaponOwnedMask, 2),
		"shop: an unowned tier 2 (MinLevel 1) is bought and equipped", show({ f.Data.WeaponTier, spent }))
end)

------------------------------------------------------------------ 6b. A23-28 weapon level rule (auto-fit on a level drop, one notice per level-up crossing)
runGroup("levelrule", function()
	local base = fixture()
	local C = base.Config
	-- Config.WeaponUsable(tier, level) = level >= Weapons[tier].MinLevel
	local usableBad = {}
	for tier = 1, C.MaxWeaponTier do
		local min = C.Weapons[tier].MinLevel
		for _, level in { 1, min - 1, min, min + 1, 100 } do
			if level >= 1 and C.WeaponUsable(tier, level) ~= (level >= min) then table.insert(usableBad, tier .. "@Lv" .. level) end
		end
	end
	check(#usableBad == 0, "Config.WeaponUsable(tier, level) = level >= Weapons[tier].MinLevel", show(usableBad))
	check(C.WeaponUsable(8, 1) and not C.WeaponUsable(3, 4) and C.WeaponUsable(3, 5) and not C.WeaponUsable(4, 11) and C.WeaponUsable(4, 12)
		and not C.WeaponUsable(6, 29) and C.WeaponUsable(6, 30), "WeaponUsable boundaries: T8 at Lv1, T3 from Lv5, T4 from Lv12, T6 from Lv30")
	check(not C.WeaponUsable(0, 50) and not C.WeaponUsable(10, 50) and not C.WeaponUsable("3", 50) and not C.WeaponUsable(nil, 50),
		"WeaponUsable of an unknown tier is false")
	check(C.WeaponUsable(9, 50) and not C.WeaponUsable(9, 49), "C1 WeaponUsable: the Mythic T9 from Lv50")
	check(C.WeaponUsable(2, nil) and not C.WeaponUsable(3, nil), "WeaponUsable with no level reads Lv1")
	-- Config.BestUsableWeapon(mask, level): the owned usable tier with the highest Damage; A23-34: 0 = bare hands when no
	-- owned weapon is usable (tier 1 is owned only after the M1_1 gift)
	for _, case in {
		{ tierMask(1, 3, 6), 1, 1, "T1+T3+T6 at Lv1 -> T1 (T3 needs Lv5, T6 Lv30)" },
		{ tierMask(1, 3, 6), 5, 3, "T1+T3+T6 at Lv5 -> T3" },
		{ tierMask(1, 3, 6), 29, 3, "T1+T3+T6 at Lv29 -> T3" },
		{ tierMask(1, 3, 6), 30, 6, "T1+T3+T6 at Lv30 -> T6" },
		{ tierMask(1, 3, 6, 8), 1, 8, "the legendary T8 (76) at Lv1" },
		{ tierMask(1, 3, 8), 5, 8, "T8 (76) beats a usable T3 (38)" },
		{ tierMask(1, 3, 4, 8), 11, 8, "T4 not usable at Lv11 -> T8" },
		{ tierMask(1, 3, 4, 8), 12, 4, "an owned usable T4 (88) beats T8 (76): by Damage, not tier number" },
		{ tierMask(1, 2), 1, 2, "T1+T2 at Lv1 -> T2" },
		{ 0, 50, 0, "nothing owned -> 0 (bare hands, A23-34)" },
		{ tierMask(3), 1, 0, "only T3 owned at Lv1 -> 0 (bare hands; tier 1 is never assumed)" },
		{ tierMask(2), 1, 2, "only T2 owned (bought before the M1_1 gift) -> T2" },
		{ tierMask(1, 2, 3, 4, 5, 6, 7, 8), 100, 7, "everything owned at Lv100 -> T7 (1000)" },
		{ tierMask(1, 2, 3, 4, 5, 6, 7, 8, 9), 100, 9, "C1 the Mythic T9 (2200) owned at Lv100 -> T9" },
		{ tierMask(1, 2, 3, 4, 5, 6, 7, 8, 9), 49, 7, "C1 T9 owned at Lv49 (needs Lv50) -> T7" },
	} do
		local got = C.BestUsableWeapon(case[1], case[2])
		check(got == case[3], "Config.BestUsableWeapon: " .. case[4], "got " .. tostring(got))
	end

	local function mk(level, tier, owned, enh, nudgeOff)
		local saved = deepCopy(DEFAULT_ROW)
		saved.Level, saved.WeaponTier, saved.WeaponOwnedMask = level, tier, owned
		saved.WeaponEnhance = enh or { 1, 2, 3, 4, 5, 6, 7, 8 }
		local x = fixture({ Saved = saved })
		x.Data.LootFlags.FirstScroll = true
		-- the real Config has the "You can now use ..." line off (Nudges.WeaponUsableNow, 검수 10/09): these checks look at the rule, so turn it on
		if not nudgeOff then x.Config.Nudges.WeaponUsableNow = true end
		return x
	end
	local function name(x, t) return C.WeaponName(t, x.Player:GetAttribute("Class") or "Warrior", x.Player:GetAttribute("Faction") or "None") end
	-- level up one level at a time through ProgressionService.AddXP (fires LeveledUp); returns { [level] = { tier named } }
	local function levelUp(x, target)
		local seen, guard = {}, 0
		while x.Data.Level < target and guard < 200 do
			guard += 1
			x.Notices = {}
			x.Prog.AddXP(x.Player, C.XPToNext(x.Data.Level) - math.floor(x.Data.XP or 0))
			for _, n in weaponNotices(x, "WeaponUsableNow") do
				seen[x.Data.Level] = seen[x.Data.Level] or {}
				table.insert(seen[x.Data.Level], n.Tier)
				check(n.Kind == "good", "A23-28 WeaponUsableNow notice kind is good", n.Kind)
			end
		end
		return seen
	end

	-- (a) the reviewer case: Lv100, tier 6 equipped, tiers 1+3+6 owned -> rebirth to Lv1. Tier 3 needs Lv5, so the best
	-- usable owned weapon at Lv1 is tier 1 (tier 3 comes back at Lv5 / via the save case (e) below)
	local enhA = { 1, 0, 3, 0, 0, 6, 0, 0, 0 } -- C1: 9 tiers
	local a = mk(100, 6, tierMask(1, 3, 6), enhA)
	check(a.Data.WeaponTier == 6 and #weaponNotices(a, "WeaponAutoSwap") == 0, "A23-28 Lv100 with tier 6 equipped: nothing to fit at join")
	a.Notices = {}
	local okA = a.Prog.TryRebirth(a.Player, "Halo")
	check(okA == true and a.Data.Level == 1 and a.Data.WeaponTier == 1 and a.Player:GetAttribute("WeaponTier") == 1,
		"A23-28 reborn Lv1 with tier 6 equipped, tiers 1+3+6 owned -> tier 1 (best usable; tier 3 needs Lv5)",
		show({ okA, a.Data.Level, a.Data.WeaponTier }))
	local swapA = weaponNotices(a, "WeaponAutoSwap")
	check(#swapA == 1 and swapA[1].Text == string.format(C.Text.WeaponAutoSwap, 30, name(a, 1)) and swapA[1].Kind == "info",
		"A23-28 the rebirth auto-swap sends one WeaponAutoSwap notice (old MinLevel 30, new weapon name, info)", show(swapA))
	check(a.Data.WeaponOwnedMask == tierMask(1, 3, 6) and a.Player:GetAttribute("WeaponOwnedMask") == tierMask(1, 3, 6),
		"A23-28 the auto-swap keeps ownership (WeaponOwnedMask untouched)", a.Data.WeaponOwnedMask)
	check(deepEqual(a.Data.WeaponEnhance, enhA), "A23-28 the auto-swap keeps every tier's +N", show(a.Data.WeaponEnhance))
	check(a.Player:GetAttribute("WeaponEnhance") == 1, "A23-28 the WeaponEnhance attribute follows the swapped-in tier", a.Player:GetAttribute("WeaponEnhance"))
	-- leveling back up: one notice per crossing of an owned stronger weapon's MinLevel, never an auto-equip
	local upA = levelUp(a, 29)
	check(upA[5] and #upA[5] == 1 and upA[5][1] == 3, "A23-28 reaching Lv5 notifies WeaponUsableNow once for the owned tier 3", show(upA))
	check(upA[6] == nil, "A23-28 no notice on the level-up after the crossing (Lv6)", show(upA[6]))
	check(upA[12] == nil and upA[20] == nil, "A23-28 no notice at unowned tiers' MinLevel (tier 4 Lv12, tier 5 Lv20)", show(upA))
	check(count(upA) == 1 and a.Data.Level == 29, "A23-28 Lv1 -> Lv29: exactly one WeaponUsableNow notice", show(upA))
	check(a.Data.WeaponTier == 1 and a.Player:GetAttribute("WeaponTier") == 1, "A23-28 level-ups never change WeaponTier (no auto-equip)",
		a.Data.WeaponTier)
	a:Equip(3)
	check(a.Data.WeaponTier == 3, "the player equips tier 3 at Lv29", a.Data.WeaponTier)
	upA = levelUp(a, 31)
	check(upA[30] and #upA[30] == 1 and upA[30][1] == 6, "A23-28 reaching Lv30 notifies WeaponUsableNow once for tier 6 (stronger than the equipped tier 3)",
		show(upA))
	check(upA[31] == nil and count(upA) == 1, "A23-28 no notice on the next level-up (Lv31)", show(upA))
	check(a.Data.WeaponTier == 3, "A23-28 reaching tier 6's MinLevel does not auto-equip it", a.Data.WeaponTier)

	-- (b) the same with the legendary also owned -> tier 8 is chosen (76 > tier 1); tier 3 at Lv5 is weaker: no notice
	local b = mk(100, 6, tierMask(1, 3, 6, 8), enhA)
	b.Notices = {}
	b.Prog.TryRebirth(b.Player, "Halo")
	local swapB = weaponNotices(b, "WeaponAutoSwap")
	check(b.Data.WeaponTier == 8 and #swapB == 1 and swapB[1].Text == string.format(C.Text.WeaponAutoSwap, 30, name(b, 8)),
		"A23-28 reborn Lv1 with tier 6 equipped and the legendary owned -> tier 8 + one notice", show({ b.Data.WeaponTier, swapB }))
	check(b.Data.WeaponOwnedMask == tierMask(1, 3, 6, 8) and b.Player:GetAttribute("WeaponEnhance") == 0, "the legendary swap keeps ownership; +N follows tier 8")
	local upB = levelUp(b, 31)
	check(upB[5] == nil, "A23-28 no notice when the newly usable owned weapon is weaker than the equipped one (tier 3 vs the legendary)", show(upB))
	check(upB[30] and upB[30][1] == 6 and count(upB) == 1 and b.Data.WeaponTier == 8, "A23-28 with the legendary equipped: one notice at Lv30 (tier 6)",
		show(upB))

	-- (c) the legendary equipped with tier 6 owned: usable at Lv1, it stays and nothing is said
	local c = mk(100, 8, tierMask(1, 6, 8))
	c.Notices = {}
	c.Prog.TryRebirth(c.Player, "Halo")
	check(c.Data.WeaponTier == 8 and #weaponNotices(c, "WeaponAutoSwap") == 0, "A23-28 an equipped legendary stays at Lv1 after rebirth (no swap, no notice)",
		show({ c.Data.WeaponTier }))

	-- (d) the free class change (ProgressionService.ResetLevel -> LevelReset) from Lv35 with tier 6 equipped
	local enhD = { 0, 4, 0, 0, 0, 9, 0, 0, 0 }
	local d = mk(35, 6, tierMask(1, 2, 6), enhD)
	d.Notices = {}
	d.Prog.ResetLevel(d.Player)
	local swapD = weaponNotices(d, "WeaponAutoSwap")
	check(d.Data.Level == 1 and d.Data.WeaponTier == 2 and #swapD == 1 and swapD[1].Text == string.format(C.Text.WeaponAutoSwap, 30, name(d, 2)),
		"A23-28 free class change (LevelReset) Lv35 -> Lv1: tier 6 swapped to tier 2 + one notice", show({ d.Data.WeaponTier, swapD }))
	check(d.Data.WeaponOwnedMask == tierMask(1, 2, 6) and deepEqual(d.Data.WeaponEnhance, enhD) and d.Player:GetAttribute("WeaponEnhance") == 4,
		"A23-28 the LevelReset swap keeps ownership and +N (attribute follows tier 2)", show(d.Data.WeaponEnhance))
	-- a multi-level jump (one AddXP, one LeveledUp) past tier 6's MinLevel: still exactly one notice
	local xp = 0
	for l = 1, 39 do xp += C.XPToNext(l) end
	d.Notices = {}
	d.Prog.AddXP(d.Player, xp)
	local nowD = weaponNotices(d, "WeaponUsableNow")
	check(d.Data.Level == 40 and #nowD == 1 and nowD[1].Tier == 6 and d.Data.WeaponTier == 2,
		"A23-28 one LeveledUp from Lv1 to Lv40: one WeaponUsableNow (tier 6), no auto-equip", show({ d.Data.Level, nowD }))

	-- 검수 10/09 (user: too kind): with the real Config the "You can now use ..." line is off; the rule (no auto-equip) is the same
	local q = mk(1, 2, tierMask(1, 2, 6), enhD, true)
	check(q.Config.Nudges.WeaponUsableNow == false, "Nudges.WeaponUsableNow is off in the real Config", tostring(q.Config.Nudges.WeaponUsableNow))
	q.Notices = {}
	q.Prog.AddXP(q.Player, xp)
	check(q.Data.Level == 40 and #weaponNotices(q, "WeaponUsableNow") == 0 and q.Data.WeaponTier == 2,
		"Nudges.WeaponUsableNow off: Lv1 -> Lv40 with tier 6 owned sends no notice and still no auto-equip", show({ q.Data.Level, weaponNotices(q, "WeaponUsableNow") }))

	-- (e) a save from before the rule (Lv10, tier 6 equipped, tiers 1+3+6): PlayerReady fits it -> tier 3 + notice
	local e = mk(10, 6, tierMask(1, 3, 6), enhA)
	local swapE = weaponNotices(e, "WeaponAutoSwap")
	check(e.Data.WeaponTier == 3 and e.Player:GetAttribute("WeaponTier") == 3 and #swapE == 1
		and swapE[1].Text == string.format(C.Text.WeaponAutoSwap, 30, name(e, 3)),
		"A23-28 PlayerReady: a saved Lv10 with tier 6 equipped (tiers 1+3+6) -> tier 3 + one notice", show({ e.Data.WeaponTier, swapE }))
	check(e.Player:GetAttribute("WeaponEnhance") == 3 and e.Data.WeaponOwnedMask == tierMask(1, 3, 6), "the join fit keeps ownership; +N follows tier 3")

	-- (f) FitWeaponToLevel(player, quiet): swaps without the notice; without quiet the notice comes
	local q = mk(30, 6, tierMask(1, 2, 6))
	q:Set("Level", 3)
	q.Notices = {}
	q.Loot.FitWeaponToLevel(q.Player, true)
	check(q.Data.WeaponTier == 2 and #weaponNotices(q, "WeaponAutoSwap") == 0 and q.Player:GetAttribute("WeaponEnhance") == 2,
		"A23-28 FitWeaponToLevel(player, true) swaps quietly (no notice)", show({ q.Data.WeaponTier, q.Notices }))
	q:Set("WeaponTier", 6)
	q.Notices = {}
	q.Loot.FitWeaponToLevel(q.Player)
	check(q.Data.WeaponTier == 2 and #weaponNotices(q, "WeaponAutoSwap") == 1, "A23-28 FitWeaponToLevel(player) without quiet sends the notice",
		show({ q.Data.WeaponTier, q.Notices }))

	-- (g) nothing happens when the equipped tier is usable, even with a stronger usable owned weapon
	local u = mk(30, 3, tierMask(1, 3, 6))
	u:Pushes()
	local before = u:State()
	u.Notices = {}
	u.Loot.FitWeaponToLevel(u.Player)
	local _, pushes = u:LastPayload()
	check(deepEqual(before, u:State()) and #u.Notices == 0 and pushes == 0,
		"A23-28 FitWeaponToLevel does nothing when the equipped tier is usable (no swap to the stronger tier 6, no notice, no push)",
		show({ u.Data.WeaponTier, #u.Notices, pushes }))
end)

------------------------------------------------------------------ 7. SellMaterials
runGroup("sell", function()
	local f = fixture()
	local L = f.L
	local stock = { Jelly = 10, SlimeCore = 3, Bone = 2, KnightCrest = 1, BruteHorn = 5, Enh70 = 4, Move30 = 1, Enh10 = 2 }
	for id, n in stock do f:Give(id, n) end
	local wantGold, wantCount = 0, 0
	for id, n in stock do
		if L.Items[id].Kind == "Material" then wantGold += n * L.Items[id].Sell; wantCount += n end
	end
	local leftAtPay = {}
	local orig = f.Prog.AddCarriedGold
	f.Prog.AddCarriedGold = function(p, amount, source)
		local mats = 0
		for id, n in f.Data.Items do if L.Items[id] and L.Items[id].Kind == "Material" then mats += n end end
		table.insert(leftAtPay, { Mats = mats, Amount = amount, Source = source })
		return orig(p, amount, source)
	end
	local function refusedCase(label, fn, notice)
		local before = f:State()
		f.Notices = {}
		local paid = #leftAtPay
		fn()
		check(deepEqual(before, f:State()) and #leftAtPay == paid, label)
		if notice then check(f:Noticed(notice) == 1, label .. " (notice)") end
	end
	f.NearAnvil = false
	refusedCase("refused away from the anvil (ShopService.CanBuyWeapon false), items unchanged", function() f:Sell() end, L.Text.SellFar)
	f.NearAnvil = true
	refusedCase("extra argument refused", function() f:Sell("x") end)
	do
		local x = fixture()
		x:Give("Jelly", 5)
		local before = x:State()
		x:Sell(nil, "x")
		check(deepEqual(before, x:State()) and #x.GoldLog == 0, "trailing extra argument refused (nil, 'x')", show(x.Data.Items))
	end
	f.Ready = false
	refusedCase("not-ready player refused", function() f:Sell() end)
	f.Ready = true
	local carried = f.Data.CarriedGold
	f.Notices = {}
	f:Sell()
	local onlyScrolls = true
	for id in f.Data.Items do if L.Items[id].Kind == "Material" then onlyScrolls = false end end
	check(onlyScrolls and f:Count("Enh70") == 4 and f:Count("Move30") == 1 and f:Count("Enh10") == 2,
		"sells only Kind == Material; scrolls stay", show(f.Data.Items))
	check(#leftAtPay == 1 and leftAtPay[1].Amount == wantGold and leftAtPay[1].Source == "Sale" and f.Data.CarriedGold == carried + wantGold,
		"pays sum(count x Sell) exactly once", show(leftAtPay))
	check(leftAtPay[1] and leftAtPay[1].Mats == 0, "materials are removed before the gold is paid")
	check(f.Data.BlacksmithVisited == true, "selling marks BlacksmithVisited")
	check(f:Noticed(string.format(L.Text.SellDone, wantCount, tostring(wantGold))) == 1, "SellDone notice with count and gold")
	local sold = f:LastPayload()
	check(sold and sold.Items.Jelly == nil and sold.Items.Enh70 == 4, "Inventory republished after the sale", show(sold and sold.Items))
	f.Notices = {}
	f:Sell()
	check(#leftAtPay == 1 and f.Data.CarriedGold == carried + wantGold, "a second sale pays nothing")
	check(f:Noticed(L.Text.SellNothing) == 1, "SellNothing notice")
	-- rate limit: two requests in the same window pay once
	f:Give("Jelly", 5)
	f.Now += 5
	f:FireRaw("SellMaterials")
	f:FireRaw("SellMaterials")
	check(#leftAtPay == 2 and leftAtPay[2].Amount == 5 * L.Items.Jelly.Sell, "SellMaterials rate limited (one payment)", #leftAtPay)
	-- 게임성 검수 2026-10-11: monster materials only; gathered ones (Source "Gather") stay for the artisans
	do
		local g = fixture()
		g:Give("Jelly", 3)
		g:Give("Herb", 4)
		g:Give("CopperOre", 2)
		g:Sell()
		local paid = 0
		for _, e in g.GoldLog do paid += e.Amount end
		check(g:Count("Jelly") == 0 and g:Count("Herb") == 4 and g:Count("CopperOre") == 2 and paid == 3 * L.Items.Jelly.Sell,
			"the sell-all keeps gathered materials (only the monster ones are sold)", show(g.Data.Items))
	end
	-- C1: the two boss materials (Source "Boss") sit on their boss's table and stay out of the sell-all
	do
		local function hasRow(kind, id, p)
			for _, row in L.Tables[kind] or {} do
				if row.Item == id and row.P == p then return true end
			end
			return false
		end
		local kj, cg = L.Items.KingJelly, L.Items.ClatterGem
		check(kj and kj.Kind == "Material" and kj.Source == "Boss" and kj.Sell == 60 and cg and cg.Kind == "Material"
			and cg.Source == "Boss" and cg.Sell == 400 and hasRow("SlimeKing", "KingJelly", 0.2)
			and hasRow("CaptainClatter", "ClatterGem", 0.1), "C1 boss materials: KingJelly (SlimeKing 0.2) / ClatterGem (CaptainClatter 0.1), Source Boss",
			show({ kj, cg }))
		local g = fixture()
		g:Give("Jelly", 2)
		g:Give("KingJelly", 3)
		g:Give("ClatterGem", 1)
		g:Sell()
		local paid = 0
		for _, e in g.GoldLog do paid += e.Amount end
		check(g:Count("KingJelly") == 3 and g:Count("ClatterGem") == 1 and g:Count("Jelly") == 0 and paid == 2 * L.Items.Jelly.Sell,
			"C1 the sell-all keeps the boss materials (sold one at a time)", show(g.Data.Items))
		-- C1 review: they drop only while crafting is on (nothing to craft them into before)
		local k = fixture()
		k.ScriptConst = 0
		k.Config.Features.Crafting = false
		k:Kill("SlimeKing")
		local off = k:Count("KingJelly")
		k.Config.Features.Crafting = true
		k:Kill("SlimeKing")
		k.Config.Features.Crafting = false
		check(kj.Feature == "Crafting" and cg.Feature == "Crafting" and off == 0 and k:Count("KingJelly") == 1,
			"C1 boss materials drop only while Features.Crafting is on", show({ off, k:Count("KingJelly") }))
	end
	-- review B10: an unknown saved id is never sold (no price) and stays in the save
	local saved = deepCopy(DEFAULT_ROW)
	saved.Items = { Bogus = 7, Jelly = 2 }
	local u = fixture({ Saved = saved })
	local before = u.Data.CarriedGold
	u:Sell()
	check(u.Data.Items.Bogus == 7 and u.Data.Items.Jelly == nil and u.Data.CarriedGold == before + 2 * L.Items.Jelly.Sell,
		"unknown ids are not sold and stay saved", show(u.Data.Items))
end)

------------------------------------------------------------------ 8. rebirth (A23-14: only Level and XP reset)
runGroup("rebirth", function()
	local saved = deepCopy(DEFAULT_ROW)
	saved.Level, saved.WeaponTier, saved.WeaponOwnedMask, saved.BankGold = 100, 8, 255, 4567
	saved.WeaponEnhance = { 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	saved.Items = { Jelly = 5, Enh30 = 2, Bogus = 1 }
	saved.LootFlags = { FirstScroll = true }
	local f = fixture({ Saved = saved })
	local C = f.Config
	f:Set("CarriedGold", 123)
	f:Set("XP", 50)
	check(f.Player:GetAttribute("WeaponEnhance") == 9, "equipped legendary +9 before rebirth")
	local before = f:State()
	local ok, reason = f.Prog.TryRebirth(f.Player, "Halo")
	check(ok == true, "TryRebirth succeeds", reason)
	check(f.Data.Level == 1 and f.Data.XP == 0 and f.Data.Rebirths == 1 and f.Player:GetAttribute("Level") == 1,
		"rebirth resets Level to 1 and XP to 0 (Rebirths 1)", show({ f.Data.Level, f.Data.XP, f.Data.Rebirths }))
	check(f.Data.WeaponOwnedMask == 255 and f.Player:GetAttribute("WeaponOwnedMask") == 255,
		"every owned weapon is kept (mask 255 incl. the legendary)", f.Data.WeaponOwnedMask)
	check(f.Data.WeaponTier == 8 and f.Player:GetAttribute("WeaponTier") == 8 and f.Player:GetAttribute("WeaponEnhance") == 9,
		"the equipped weapon stays equipped with its +9", show({ f.Data.WeaponTier, f.Player:GetAttribute("WeaponEnhance") }))
	check(deepEqual(f.Data.WeaponEnhance, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }), "WeaponEnhance is not reset by rebirth", show(f.Data.WeaponEnhance))
	check(deepEqual(f.Data.Items, before.Items) and deepEqual(f.Data.LootFlags, before.Flags),
		"items (incl. unknown saved ids) and LootFlags are kept", show(f.Data.Items))
	check(f.Data.CarriedGold == 123 and f.Data.BankGold == 4567, "carried and bank gold are kept",
		show({ f.Data.CarriedGold, f.Data.BankGold }))
	-- A23-28: the legendary (MinLevel 1) stays usable at Lv1, so the level fit changes nothing and says nothing
	check(#weaponNotices(f, "WeaponAutoSwap") == 0, "A23-28 an equipped legendary needs no auto-swap after rebirth (no WeaponAutoSwap notice)",
		show(weaponNotices(f, "WeaponAutoSwap")))
	-- A23-28: a kept weapon above the new level stays owned with its +N but cannot be equipped until the level is back
	f.Notices = {}
	f:Equip(5)
	check(f.Data.WeaponTier == 8 and f:Noticed(string.format(C.Text.EquipNeedLevel, C.Weapons[5].MinLevel)) == 1
		and f.Data.WeaponOwnedMask == 255 and f.Data.WeaponEnhance[5] == 6,
		"A23-28 reborn Lv1 player cannot equip the kept tier 5 (EquipNeedLevel 20); ownership and its +6 stay",
		show({ f.Data.WeaponTier, f.Data.WeaponOwnedMask, f.Data.WeaponEnhance[5] }))
	f:Equip(1)
	check(f.Data.WeaponTier == 1 and f.Player:GetAttribute("WeaponEnhance") == 2, "reborn Lv1 player equips tier 1 (+2)",
		show({ f.Data.WeaponTier, f.Player:GetAttribute("WeaponEnhance") }))
	f:Equip(8)
	check(f.Data.WeaponTier == 8 and f.Player:GetAttribute("WeaponEnhance") == 9, "and swaps back to the legendary with its +9")
	f:Release()
	local re = fixture({ Rows = f.Rows, UserId = f.UserId })
	check(deepEqual(re.Data.WeaponEnhance, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }) and re.Data.WeaponOwnedMask == 255 and re.Data.WeaponTier == 8
		and re.Data.Level == 1 and re.Data.Rebirths == 1 and re.Data.Items.Bogus == 1 and re.Data.Items.Jelly == 5,
		"weapons, enhancement, items and the reset level survive save / reload after rebirth", show({ re.Data.WeaponOwnedMask, re.Data.Level }))
	check(re.Data.BankGold == 4567 + 123, "gold survives the reload (carried gold banked on leave)", re.Data.BankGold)
	-- a faction switch at rebirth uses the same rule
	local s2 = deepCopy(saved)
	s2.WeaponOwnedMask, s2.WeaponTier = 127, 7
	local g = fixture({ Saved = s2 })
	ok = g.Prog.TryRebirth(g.Player, "Horns")
	-- A23-28: the Lv40 tier 7 is not usable at Lv1 -> the best usable owned weapon (tiers 1..7 owned: tier 2, damage 15)
	check(ok == true and g.Data.WeaponOwnedMask == 127 and g.Data.WeaponTier == 2 and g.Data.BankGold == 4567
		and deepEqual(g.Data.WeaponEnhance, { 2, 3, 4, 5, 6, 7, 8, 9, 10 }) and g.Data.Level == 1,
		"rebirth with a faction switch keeps weapons / gold / enhancement; the Lv40 tier 7 is auto-swapped to tier 2",
		show({ g.Data.WeaponOwnedMask, g.Data.WeaponTier }))
	check(g:Noticed(string.format(C.Text.WeaponAutoSwap, 40, C.WeaponName(2, "Warrior", "Horns"))) == 1
		and g.Player:GetAttribute("WeaponEnhance") == 3, "A23-28 faction-switch rebirth: one WeaponAutoSwap notice (Lv40 -> tier 2), +N follows",
		show({ g.Player:GetAttribute("WeaponEnhance") }))
	check(g.Player:GetAttribute("Faction") == "Horns", "the faction switch happened", g.Player:GetAttribute("Faction"))
	-- below the rebirth level nothing changes
	local low = deepCopy(saved)
	low.Level = 10
	local h = fixture({ Saved = low })
	local hb = h:State()
	ok = h.Prog.TryRebirth(h.Player, "Halo")
	check(ok == false and deepEqual(hb, h:State()), "rebirth below the required level is refused and changes nothing")
end)

------------------------------------------------------------------ 9. damage
runGroup("damage", function()
	local f = { Now = 100, Time = 1.8e9, Warnings = {}, Tasks = {}, PlayerList = {}, Deferred = {}, Dead = false }
	table.insert(groupFixtures, f)
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local L = C.Loot
	local function expectedMult(e)
		if type(e) ~= "number" or e ~= e or math.abs(e) == math.huge then return 1 end
		return 1 + L.EnhancePerLevel * math.clamp(math.floor(e), 0, L.MaxEnhance)
	end
	local bad = 0
	for tier = 1, C.MaxWeaponTier do
		for _, level in { 1, 7, 50, 100 } do
			for _, e in { "none", 0 / 0, math.huge, -math.huge, -3, 0, 1, 2.9, 5, 9.99, 10, 11, 1e9, "3" } do
				local arg = e ~= "none" and e or nil
				local want = C.Weapons[tier].Damage * (1 + C.Combat.LevelDamagePerLevel * (level - 1)) * expectedMult(arg)
				local got = C.WeaponDamage(tier, level, arg)
				if math.abs(got - want) > 1e-9 * math.max(1, want) then
					bad += 1
					if bad <= 3 then check(false, "WeaponDamage sample", show({ tier, level, e, got, want })) end
				end
			end
		end
	end
	check(bad == 0, "WeaponDamage(t, l, e) = base x (1 + 0.1 x clamp(floor(e), 0, 10)); nil/NaN/inf/non-number -> x1", bad)
	check(C.EnhanceMult(10) == 2 and C.EnhanceMult(0) == 1 and C.EnhanceMult(nil) == 1 and C.EnhanceMult(0 / 0) == 1
		and C.EnhanceMult(15) == 2 and C.EnhanceMult(-2) == 1, "EnhanceMult endpoints (+10 = x2)")
	-- review B3: the legendary is exactly 2 x the best shop tier (3) and stays below the tier-4 drop
	check(C.WeaponDamage(8, 1) == 2 * C.WeaponDamage(C.WeaponShop.MaxSoldTier, 1) and C.WeaponDamage(8, 1) < C.WeaponDamage(4, 1),
		"legendary base damage = 2 x the best shop tier, below tier 4", C.WeaponDamage(8, 1))
	-- review B5: Config.PowerOf(level, tier, mult, enhance) = sqrt(WeaponDamage(tier, level, enhance) x BaseHealth(level)) x mult
	local powerBad = 0
	for tier = 1, C.MaxWeaponTier do
		for _, level in { 1, 9, 30, 100 } do
			for _, e in { 0, 3, 10 } do
				local want = math.sqrt(C.WeaponDamage(tier, level, e) * C.BaseHealth(level)) * 1.25
				if math.abs(C.PowerOf(level, tier, 1.25, e) - want) > 1e-9 * want then powerBad += 1 end
			end
		end
	end
	check(powerBad == 0, "PowerOf uses the enhanced weapon damage", powerBad)
	check(math.abs(C.PowerOf(20, 3, 1, 10) / C.PowerOf(20, 3, 1, 0) - math.sqrt(2)) < 1e-9, "+10 = x2 damage = x sqrt(2) power")
	check(C.PowerOf(20, 3, 1, nil) == C.PowerOf(20, 3, 1, 0) and C.PowerOf(20, 3, 1, 0 / 0) == C.PowerOf(20, 3, 1, 0)
		and C.PowerOf(20, 3, 1, 15) == C.PowerOf(20, 3, 1, 10) and C.PowerOf(20, 3, nil, 0) == C.PowerOf(20, 3, 1, 0),
		"PowerOf: missing / NaN enhance = +0, clamped at +10, missing mult = 1")
	check(math.abs(C.PowerOf(1, 8, 1, 0) / C.PowerOf(1, 3, 1, 0) - math.sqrt(2)) < 1e-9, "legendary power = sqrt(2) x iron (2 x damage)")
	-- JusticeService.GetPower / GetCombatPower and the PvPService combatPower fallback read the WeaponEnhance attribute
	local justice = execute("JusticeService power", JUSTICE_POWER_SOURCE, {}, C)
	local pvpPower = execute("PvPService combatPower", PVP_POWER_SOURCE, {}, C)
	local function attrPlayer(attrs)
		local p = { Attrs = attrs }
		function p:GetAttribute(k) return self.Attrs[k] end
		return p
	end
	local hero = attrPlayer({ Level = 30, WeaponTier = 3, WeaponEnhance = 10, RebirthBonus = 0.5 })
	local plain = attrPlayer({ Level = 30, WeaponTier = 3, WeaponEnhance = 0, RebirthBonus = 0.5 })
	local noAttr = attrPlayer({ Level = 30, WeaponTier = 3, RebirthBonus = 0.5 })
	check(math.abs(justice.GetPower(hero) - C.PowerOf(30, 3, 1.5, 10)) < 1e-9 and justice.GetPower(hero) > justice.GetPower(plain),
		"JusticeService.GetPower passes the WeaponEnhance attribute (rebirth bonus included)", show({ justice.GetPower(hero), justice.GetPower(plain) }))
	-- BB4: the combat power is the displayed integer Config.CombatPower (PowerOf x DisplayScale, rounded)
	check(justice.GetCombatPower(hero) == C.CombatPower(30, 3, 10) and C.CombatPower(30, 3, 10) == math.floor(C.PowerOf(30, 3, 1, 10) * 10 + 0.5),
		"JusticeService.GetCombatPower passes the WeaponEnhance attribute (no rebirth bonus)", justice.GetCombatPower(hero))
	check(justice.GetCombatPower(noAttr) == C.CombatPower(30, 3, 0), "missing WeaponEnhance attribute = +0")
	-- PvPService: J missing -> its own fallback (data.WeaponEnhance is the per-tier TABLE, so it must read the attribute)
	local fallbackS = { PlayerService = { GetData = function() return { Level = 30, WeaponTier = 3, WeaponEnhance = { 9, 9, 9, 9, 9, 9, 9, 9 } } end } }
	check(pvpPower.combatPower(hero, fallbackS) == C.CombatPower(30, 3, 10),
		"PvPService combatPower fallback reads the WeaponEnhance attribute (not the per-tier table)", pvpPower.combatPower(hero, fallbackS))
	local viaJ = { PlayerService = fallbackS.PlayerService, JusticeService = { GetCombatPower = function() return 1234 end } }
	check(pvpPower.combatPower(hero, viaJ) == 1234, "PvPService combatPower prefers JusticeService.GetCombatPower")
	-- SwingHitsToKill uses the same enhancement
	local swingBad, monotone = 0, true
	for monsterId, m in C.MonsterTypes do
		for classId, cdef in C.Classes do
			local prev = math.huge
			for e = 0, 10 do
				local per = C.WeaponDamage(1, 1, e) * (cdef.Damage or 1) * (1 + 0.15) * C.BasicSkill.SwingImmediate
				per = math.max(1, math.floor(per + 0.5))
				local want = math.ceil(m.HP / per)
				local got = C.SwingHitsToKill(1, 1, classId, monsterId, "Horns", e)
				if got ~= want then swingBad += 1 end
				if got > prev then monotone = false end
				prev = got
			end
		end
	end
	check(swingBad == 0, "SwingHitsToKill(..., enhance) uses the enhanced weapon damage", swingBad)
	check(monotone, "more enhancement never needs more hits")
	check(C.SwingHitsToKill(1, 1, "Warrior", "Slime", nil) == C.SwingHitsToKill(1, 1, "Warrior", "Slime", nil, 0), "missing enhance = +0")

	-- CombatService: real ComputeMonsterHit / ComputePvPHit with the WeaponEnhance attribute
	local w = world(f, C, {})
	local util = execute("Util", UTIL_SOURCE, w.Env())
	w.Modules.Util = util
	w.Modules.Net = { Get = function() return { OnServerEvent = signal() } end, Notify = function() end, NotifyAll = function() end, Fx = function() end }
	local combat = execute("CombatService", COMBAT_SOURCE, w.Env())
	local registry = {
		PlayerService = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterDied = signal(), CharacterSpawned = signal(),
			GetReadyPlayers = function() return {} end, IsReady = function() return true end },
		FactionService = { FactionChanged = signal(), GetFaction = function(p) return p:GetAttribute("Faction") end,
			GetPerks = function(p) return C.Factions[p:GetAttribute("Faction")] end },
		ClassService = { ClassChanged = signal(), GetClass = function(p) return p:GetAttribute("Class") end,
			GetClassDef = function(p) return C.Classes[p:GetAttribute("Class")] end },
		PvPService = { GetStars = function() return 0 end, HasRevenge = function() return false end },
		JusticeService = { GetDamageMult = function() return 1 end },
		KaijuService = { GetState = function() return "None" end },
	}
	combat.Init(registry)
	local nextId = 0
	local function fighter(tier, level, enhance, faction, class)
		nextId += 1
		local p = newPlayer(f, nextId, w.Players)
		p.Attrs = { WeaponTier = tier, Level = level, WeaponEnhance = enhance, Faction = faction or "Neutral", Class = class or "Warrior" }
		return p
	end
	local a0 = fighter(1, 1, 0)
	local base = combat.ComputeMonsterHit(a0, false)
	for _, case in { { 10, 2 }, { 5, 1.5 }, { 0 / 0, 1 }, { nil, 1 }, { 3.7, 1.3 } } do
		local a = fighter(1, 1, case[1])
		local hit = combat.ComputeMonsterHit(a, false)
		check(math.abs(hit - base * case[2]) < 1e-9, "ComputeMonsterHit scales with the WeaponEnhance attribute", show({ case[1], hit, base }))
	end
	local PvP = C.PvP
	local function ratio(a, v)
		local c = C.Classes[a:GetAttribute("Class")]
		local denom = C.MaxHealth(v:GetAttribute("Level"), v:GetAttribute("Faction"), v:GetAttribute("Class")) * PvP.HitPctOfMaxHP
			* (c.Damage or 1) * (1 + combat.GetDamageBonus(a, v)) * combat.GetDamageMult(a, v)
		return combat.ComputePvPHit(a, v) / denom
	end
	local cases = {
		{ { 8, 100, 10 }, { 1, 1, 0 }, PvP.PowerRatioMax, "tier 8 +10 Lv100 vs tier 1 +0 Lv1 clamps at PowerRatioMax" },
		{ { 1, 1, 0 }, { 8, 100, 10 }, PvP.PowerRatioMin, "tier 1 +0 vs tier 8 +10 clamps at PowerRatioMin" },
		{ { 2, 1, 2 }, { 2, 1, 0 }, 1.2, "enhancement moves the ratio (+2 vs +0 = 1.2)" },
		{ { 1, 1, 10 }, { 1, 1, 0 }, math.min(2, PvP.PowerRatioMax), "+10 vs +0 on the same weapon is clamped" },
		{ { 2, 1, 0 }, { 2, 1, 5 }, math.max(1 / 1.5, PvP.PowerRatioMin), "victim enhancement lowers the ratio (clamped)" },
		{ { 3, 10, 4 }, { 3, 10, 4 }, 1, "equal gear = ratio 1" },
	}
	for _, case in cases do
		for _, fac in { "Neutral", "Horns", "Halo" } do
			local a = fighter(case[1][1], case[1][2], case[1][3], fac, "Archer")
			local v = fighter(case[2][1], case[2][2], case[2][3], "Halo", "Mage")
			local r = ratio(a, v)
			check(math.abs(r - case[3]) < 1e-9, case[4], show({ fac, r }))
		end
	end
	local sweepBad = 0
	for at = 1, 8 do
		for ae = 0, 10, 5 do
			for vt = 1, 8, 7 do
				for ve = 0, 10, 10 do
					local r = ratio(fighter(at, 50, ae), fighter(vt, 1, ve))
					if r < PvP.PowerRatioMin - 1e-9 or r > PvP.PowerRatioMax + 1e-9 then sweepBad += 1 end
				end
			end
		end
	end
	check(sweepBad == 0, "ComputePvPHit ratio always within [PowerRatioMin, PowerRatioMax]", sweepBad)
end)

------------------------------------------------------------------ summary
local list = {}
for _, key in order do
	local r = results[key]
	table.insert(list, { Group = r.Group, Name = r.Name, Pass = r.Pass, Fail = r.Fail, FirstFailure = r.First })
end
print("LOOT_RESULT_JSON " .. JSON.encode({ Checks = total, Failed = failedCount, Named = list, Stats = stats, Findings = findings }))
if failedCount == 0 then
	print("LOOT_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
else
	print("LOOT_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
end
