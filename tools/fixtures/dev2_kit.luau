-- dev2_kit.luau : shared offline doubles for the 게임성 개발 2 (server session) checks. tools/dev2_offline.py puts the
-- suite's source bindings (long-string locals) and SUITE_MARK in front of this file and the suite fixture after it.
-- Only engine / service boundaries are doubles (Players, Instances, DataStores incl. ordered stores and request
-- budgets, UserService, HttpService JSON, task, os, Random). The game modules themselves always run from the CURRENT
-- sources. Every check is named and collected (a failure never aborts the run); the result is one JSON line.

------------------------------------------------------------------ check collection
local results, order, findings = {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
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
	groupWorlds = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	local warnings = {}
	for _, w in groupWorlds do
		for _, text in w.Warnings do
			-- w.AllowWarn: one expected substring, or a list of them
			local allowed = false
			for _, part in (type(w.AllowWarn) == "table" and w.AllowWarn or { w.AllowWarn }) do
				if string.find(text, part, 1, true) then allowed = true end
			end
			if not allowed then table.insert(warnings, text) end
		end
	end
	check(#warnings == 0, "no service warnings (pcall-swallowed handler errors)", warnings[1])
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

local function execute(name, source, env, ...)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn(...)
end

------------------------------------------------------------------ JSON (HttpService double)
local function jsonEncode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then
		assert(v == v and v ~= math.huge and v ~= -math.huge, "JSONEncode: invalid number")
		return (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.17g", v)
	end
	if t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	assert(t == "table", "JSONEncode: cannot encode " .. t)
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, jsonEncode(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do
		assert(type(k) == "string", "JSONEncode: mixed / non-string keys")
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, jsonEncode(k) .. ":" .. jsonEncode(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function jsonDecode(text)
	local i = 1
	local function ws() i = string.find(text, "[^ \t\r\n]", i) or #text + 1 end
	local value
	local function str()
		local out = {}
		i += 1
		while true do
			local c = string.sub(text, i, i)
			if c == '"' then i += 1; return table.concat(out) end
			if c == "\\" then
				local e = string.sub(text, i + 1, i + 1)
				if e == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(text, i + 2, i + 5), 16)))
					i += 6
				else
					table.insert(out, ({ n = "\n", t = "\t", r = "\r" })[e] or e)
					i += 2
				end
			else
				table.insert(out, c)
				i += 1
			end
		end
	end
	function value()
		ws()
		local c = string.sub(text, i, i)
		if c == "{" then
			local out = {}
			i += 1
			ws()
			if string.sub(text, i, i) == "}" then i += 1; return out end
			while true do
				ws()
				local k = str()
				ws()
				i += 1 -- :
				out[k] = value()
				ws()
				local d = string.sub(text, i, i)
				i += 1
				if d == "}" then return out end
			end
		elseif c == "[" then
			local out = {}
			i += 1
			ws()
			if string.sub(text, i, i) == "]" then i += 1; return out end
			while true do
				table.insert(out, value())
				ws()
				local d = string.sub(text, i, i)
				i += 1
				if d == "]" then return out end
			end
		elseif c == '"' then
			return str()
		elseif string.sub(text, i, i + 3) == "true" then
			i += 4; return true
		elseif string.sub(text, i, i + 4) == "false" then
			i += 5; return false
		elseif string.sub(text, i, i + 3) == "null" then
			i += 4; return nil
		end
		local s, e = string.find(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", i)
		assert(s, "JSONDecode: bad text at " .. i)
		i = e + 1
		return tonumber(string.sub(text, s, e))
	end
	return value()
end

------------------------------------------------------------------ engine doubles
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

-- a seeded Random; w.Script = { numbers } overrides the next NextNumber draws (front first)
local function randomDouble(w)
	return { new = function()
		local state = 12345
		local r = {}
		local function nextFloat()
			if w and w.Script and #w.Script > 0 then return table.remove(w.Script, 1) end
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
end

-- Instances: a tiny tree (Name / Parent / children / FindFirstChild / Destroy / attributes) for Folder / IntValue / ...
local instMeta = {}
local function newInstance(className, w)
	local o = { __kind = "Instance", ClassName = className, Name = className, _children = {}, _parent = nil, Attrs = {},
		Signals = {}, _world = w }
	return setmetatable(o, instMeta)
end
instMeta.__index = function(o, key)
	if key == "Parent" then return rawget(o, "_parent") end
	local m = instMeta.Methods[key]
	if m then return m end
	return nil
end
instMeta.__newindex = function(o, key, value)
	if key == "Parent" then
		local old = rawget(o, "_parent")
		if old then
			local i = table.find(old._children, o)
			if i then table.remove(old._children, i) end
		end
		rawset(o, "_parent", value)
		if type(value) == "table" and value._children then table.insert(value._children, o) end
		return
	end
	rawset(o, key, value)
end
instMeta.Methods = {
	IsA = function(o, kind) return o.ClassName == kind or kind == "Instance" end,
	FindFirstChild = function(o, name)
		for _, c in o._children do if c.Name == name then return c end end
		return nil
	end,
	FindFirstChildOfClass = function(o, className)
		for _, c in o._children do if c.ClassName == className then return c end end
		return nil
	end,
	GetChildren = function(o) return table.clone(o._children) end,
	Destroy = function(o) o.Parent = nil; o.Destroyed = true end,
	GetAttribute = function(o, k) return o.Attrs[k] end,
	SetAttribute = function(o, k, v)
		if o.Log then table.insert(o.Log, { Key = k, Value = v }) end
		if o.Attrs[k] == v then return end
		o.Attrs[k] = v
		local s = o.Signals[k]
		if s then s:Fire() end
	end,
	GetAttributeChangedSignal = function(o, k)
		o.Signals[k] = o.Signals[k] or rbxSignal(o._world and o._world.Warnings or {})
		return o.Signals[k]
	end,
}

------------------------------------------------------------------ world
-- opts: Time (os.time), Clock (os.clock), Studio (RunService:IsStudio, default true), PrivateServerId, EditConfig(config),
-- Budget = { [request type] = n } (default 100), Friends = { ["a:b"] = true }, FriendError = { ["a:b"] = true },
-- Stores = a DataStore table shared with another world (= another server of the same game)
local W = { Serial = 0, Guid = 0 }
local function newWorld(opts)
	opts = opts or {}
	W.Serial += 1
	local w = { Clock = opts.Clock or 1000, Time = opts.Time or 1790000000, Deferred = {}, Spawned = {}, Delayed = {},
		Warnings = {}, PlayerList = {}, Ready = {}, Notices = {}, All = {}, Fx = {}, Fired = {}, Stores = opts.Stores or {},
		DSCalls = {},
		Budget = opts.Budget or {}, Fail = {}, Friends = opts.Friends or {}, FriendError = opts.FriendError or {},
		FriendCalls = 0, UserInfoCalls = 0, Script = nil }
	table.insert(groupWorlds, w)
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	if opts.EditConfig then opts.EditConfig(config) end
	w.Config = config

	local players = newInstance("Players", w)
	players.Name = "Players"
	players.PlayerRemoving = rbxSignal(w.Warnings)
	players.PlayerAdded = rbxSignal(w.Warnings)
	function players.GetPlayers(_)
		local out = {}
		for _, p in w.PlayerList do if p.Parent == players then table.insert(out, p) end end
		return out
	end
	function players.GetPlayerByUserId(_, id)
		for _, p in w.PlayerList do if p.UserId == id and p.Parent == players then return p end end
		return nil
	end
	w.Players = players

	-- DataStores: standard + ordered, request budgets, failure injection (w.Fail["<store>:<Op>"] = n next calls fail)
	local function failing(name, op)
		local k = name .. ":" .. op
		local n = w.Fail[k]
		if n and n > 0 then
			w.Fail[k] = n - 1
			error("offline DataStore failure " .. k)
		end
		local any = w.Fail["*:" .. op]
		if any and any > 0 then
			w.Fail["*:" .. op] = any - 1
			error("offline DataStore failure *:" .. op)
		end
	end
	local function storeOf(name, kind)
		local s = w.Stores[name]
		if not s then
			s = { Name = name, Kind = kind, Rows = {} }
			w.Stores[name] = s
		end
		local api = {}
		local function log(op, key, value) table.insert(w.DSCalls, { Op = op, Store = name, Key = key, Value = value }) end
		function api.GetAsync(_, key) failing(name, "Get"); log("Get", key); return deepCopy(s.Rows[key]) end
		-- w.OnSet(storeName, key, value): runs while the write is "in flight" (what another thread may do during the yield)
		function api.SetAsync(_, key, value)
			failing(name, "Set")
			log("Set", key, value)
			if w.OnSet then w.OnSet(name, key, value) end
			s.Rows[key] = deepCopy(value)
		end
		function api.RemoveAsync(_, key)
			failing(name, "Remove")
			log("Remove", key)
			local old = s.Rows[key]
			s.Rows[key] = nil
			return deepCopy(old)
		end
		-- w.BeforeUpdate(storeName, key): runs before the transform reads the row (another server wrote first)
		function api.UpdateAsync(_, key, fn)
			failing(name, "Update")
			if w.BeforeUpdate then w.BeforeUpdate(name, key) end
			local nextValue = fn(deepCopy(s.Rows[key]))
			log("Update", key, nextValue)
			if nextValue ~= nil then s.Rows[key] = deepCopy(nextValue) end
			return deepCopy(s.Rows[key])
		end
		function api.IncrementAsync(_, key, delta)
			failing(name, "Increment")
			s.Rows[key] = (s.Rows[key] or 0) + delta
			log("Increment", key, s.Rows[key])
			return s.Rows[key]
		end
		if kind == "Ordered" then
			function api.GetSortedAsync(_, ascending, pageSize)
				failing(name, "Sorted")
				log("Sorted", nil, pageSize)
				local list = {}
				for k, v in s.Rows do table.insert(list, { key = k, value = v }) end
				table.sort(list, function(a, b)
					if a.value ~= b.value then
						if ascending then return a.value < b.value end
						return a.value > b.value
					end
					return a.key < b.key
				end)
				local page = {}
				for i = 1, math.min(pageSize, #list) do page[i] = list[i] end
				return { IsFinished = true, GetCurrentPage = function() return page end, AdvanceToNextPageAsync = function() end }
			end
		end
		return api
	end
	w.StoreOf = storeOf
	local dss = {}
	function dss.GetDataStore(_, name, scope) return storeOf(scope and (name .. "@" .. scope) or name, "Standard") end
	function dss.GetOrderedDataStore(_, name, scope) return storeOf(scope and (name .. "@" .. scope) or name, "Ordered") end
	function dss.GetRequestBudgetForRequestType(_, kind)
		local n = w.Budget[tostring(kind)]
		return n == nil and 100 or n
	end
	local userService = {}
	function userService.GetUserInfosByUserIdsAsync(_, ids)
		w.UserInfoCalls += 1
		if w.UserInfoFails then error("offline UserService failure") end
		local out = {}
		for _, id in ids do table.insert(out, { Id = id, Username = "user" .. id, DisplayName = "Disp" .. id }) end
		return out
	end

	local shared = { Config = "Config", Util = "Util", Net = "Net" }
	function shared.WaitForChild(self, n) return assert(rawget(self, n), "WaitForChild " .. tostring(n)) end
	function shared.FindFirstChild(self, n) return rawget(self, n) end
	local replicated = { Shared = shared }
	function replicated.WaitForChild(self, n) return assert(rawget(self, n), "WaitForChild " .. tostring(n)) end
	local services = {
		Players = players, ReplicatedStorage = replicated, DataStoreService = dss, UserService = userService,
		RunService = { IsStudio = function() return opts.Studio ~= false end, IsServer = function() return true end,
			IsClient = function() return false end },
		HttpService = { GenerateGUID = function() W.Guid += 1; return "guid-" .. W.Guid end,
			JSONEncode = function(_, v) return jsonEncode(v) end, JSONDecode = function(_, t) return jsonDecode(t) end },
	}
	w.Services = services
	local game = { JobId = "offline-dev2", PlaceId = 81671223175574, PrivateServerId = opts.PrivateServerId or "",
		GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	w.Game = game
	w.BoundToClose = {}
	function game.BindToClose(_, fn) table.insert(w.BoundToClose, fn) end
	local osDouble = { clock = function() return w.Clock end, time = function() return math.floor(w.Time) end, date = os.date }
	local modules = { Config = config }
	local env = nativeEnv()
	env.game = game
	env.workspace = { GetServerTimeNow = function() return w.Time end }
	env.typeof = typeofDouble
	env.os = osDouble
	env.Random = randomDouble(w)
	env.print = function() end
	env.warn = function(...) table.insert(w.Warnings, table.concat({ ... }, " ")) end
	env.Instance = { new = function(className) return newInstance(className, w) end }
	env.task = {
		spawn = function(fn, ...) table.insert(w.Spawned, table.pack(fn, ...)) end,
		wait = function() error("unexpected yield") end,
		delay = function(t, fn, ...) table.insert(w.Delayed, { At = w.Clock + (tonumber(t) or 0), Job = table.pack(fn, ...) }) end,
		defer = function(fn, ...) table.insert(w.Deferred, table.pack(fn, ...)) end,
	}
	env.require = function(name) return assert(modules[name], "unexpected require " .. tostring(name)) end
	function w:Env()
		local e = {}
		for k, v in env do e[k] = v end
		return e
	end

	local util = execute("Util", UTIL_SOURCE, w:Env())
	modules.Util = util
	w.Util = util
	-- Net double: remotes record FireClient / FireAllClients; Notify / NotifyAll / Fx are logged
	local remotes = {}
	local net = { Names = {} }
	function net.Get(name)
		if not remotes[name] then
			local r = { Name = name, OnServerEvent = rbxSignal(w.Warnings) }
			function r.FireClient(_, p, payload) table.insert(w.Fired, { Remote = name, Player = p, Payload = payload }) end
			function r.FireAllClients(_, payload) table.insert(w.Fired, { Remote = name, All = true, Payload = payload }) end
			remotes[name] = r
		end
		return remotes[name]
	end
	local gameState = newInstance("Folder", w)
	function net.GameState() return gameState end
	function net.Notify(player, text, kind, secs, sound)
		table.insert(w.Notices, { Player = player, Text = text, Kind = kind, Sound = sound })
	end
	function net.NotifyAll(text, kind, secs, sound) table.insert(w.All, { Text = text, Kind = kind, Sound = sound }) end
	function net.Fx(player, kind, data) table.insert(w.Fx, { Player = player, Kind = kind, Data = data }) end
	modules.Net = net
	w.Net, w.Remotes, w.GameState = net, remotes, gameState

	-- a Player: Roblox-like attributes (changed signals fire only on a real change), Log of every SetAttribute
	function w:NewPlayer(userId, attrs)
		local p = newInstance("Player", w)
		p.Name = "P" .. userId
		p.DisplayName = "P" .. userId
		p.UserId = userId
		p.AccountAge = 30
		p.Log = {}
		p.Parent = players
		for k, v in attrs or {} do p.Attrs[k] = v end
		function p.Kick(self, msg) self.Kicked = msg end
		function p.IsFriendsWith(self, otherId)
			w.FriendCalls += 1
			local k = math.min(self.UserId, otherId) .. ":" .. math.max(self.UserId, otherId)
			if w.FriendError[k] then error("offline friends failure") end
			return w.Friends[k] == true
		end
		table.insert(w.PlayerList, p)
		return p
	end
	function w:Remove(p)
		p.Parent = nil
		local i = table.find(self.PlayerList, p)
		if i then table.remove(self.PlayerList, i) end
	end
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
	-- run queued task.spawn jobs (and the ones they queue) once each, in order; returns how many ran
	function w:RunSpawned()
		local ran = 0
		while #self.Spawned > 0 do
			local job = table.remove(self.Spawned, 1)
			ran += 1
			job[1](table.unpack(job, 2, job.n))
		end
		return ran
	end
	-- advance both clocks by `seconds` and run every task.delay that came due (in time order)
	function w:Advance(seconds)
		self.Clock += seconds
		self.Time += seconds
		table.sort(self.Delayed, function(a, b) return a.At < b.At end)
		local due = {}
		local keep = {}
		for _, d in self.Delayed do
			if d.At <= self.Clock then table.insert(due, d) else table.insert(keep, d) end
		end
		self.Delayed = keep
		for _, d in due do d.Job[1](table.unpack(d.Job, 2, d.Job.n)) end
		self:Flush()
	end
	function w:Load(name, source)
		local m = execute(name, source, self:Env())
		modules[name] = m
		return m
	end
	-- notices / server-wide lines since index `from`
	-- sound_spec 2026-10-07 §4-1: the Sound key of p's notices since `from` ("-" for a notice without one)
	function w:SoundsFor(p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Notices do
			local n = self.Notices[i]
			if n.Player == p then table.insert(out, n.Sound or "-") end
		end
		return out
	end
	function w:NoticesFor(p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Notices do
			local n = self.Notices[i]
			if n.Player == p then table.insert(out, n.Text) end
		end
		return out
	end
	return w
end

------------------------------------------------------------------ result
local function finish()
	local list = {}
	for _, key in order do
		local r = results[key]
		table.insert(list, { Group = r.Group, Name = r.Name, Pass = r.Pass, Fail = r.Fail, FirstFailure = r.First })
	end
	print(SUITE_MARK .. "_RESULT_JSON " .. jsonEncode({ Checks = total, Failed = failedCount, Named = list, Findings = findings }))
	if failedCount == 0 then
		print(SUITE_MARK .. "_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
	else
		print(SUITE_MARK .. "_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
	end
end
