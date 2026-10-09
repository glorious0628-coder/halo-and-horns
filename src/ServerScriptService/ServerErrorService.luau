-- ServerErrorService.luau : the server error record (시스템 점검 1회차 "더할 것 ③", 게임성 개발 3, 2026-10-09; contract
-- docs/design/ops_safety_server_2026-10-09.md). Read-only observer, like TelemetryService: it never changes game state.
--   * ScriptContext.Error (an uncaught script error) and a slow server tick (one Heartbeat longer than
--     Config.ServerErrors.SlowSeconds) are written to ONE analytics event, "ServerError" (value = 1 for an error, the
--     milliseconds for a slow tick; custom fields: the script name, the message, "Error" | "Slow"), at most MaxPerMinute a
--     minute for the whole server (the Roblox limit is 100 event names; this uses one). No names, UserIds or chat: digits runs
--     of 3+ become '#', messages are cut short. With nobody on the server there is no player to log the event for: the record
--     below still keeps it.
--   * The last Keep (50) records are kept in memory, the same error in a row only adds a count, and every StoreSeconds and when
--     the server closes they are merged into one DataStore document (Config.StoreName(Config.ServerErrors.Store), key "Recent",
--     newest first) so Studio can read them: DebugCommand("Errors") reads this server's list, DebugCommand("Errors", "stored")
--     the saved document of this environment (Studio: its own "_STUDIO" copy), ("Errors", "live") the real game's.
-- Entry: { T = os.time(), K = "Error" | "Slow", S = script name, M = message, N = how many times in a row }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local ServerErrorService = {}

local TAG = "ServerErrorService"
local S = nil
local E = Config.ServerErrors or {}
-- RING = the newest entries first; PENDING = entries not yet merged into the document; WINDOW = the minute's count
local RING, PENDING = {}, {}
local WINDOW = { At = 0, N = 0 }
local DIRTY = false
local STORE = nil

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

------------------------------------------------------------------ cleaning (no names, no ids, short)
-- the record text of a script name / a message: one line, digit runs of 3+ become '#', cut to `max` letters
function ServerErrorService.Clean(text, max)
	text = tostring(text == nil and "" or text)
	text = string.gsub(text, "[%c]+", " ")
	text = string.gsub(text, "%d%d%d+", "#")
	text = string.gsub(text, "%s+", " ")
	text = string.match(text, "^%s*(.-)%s*$") or ""
	max = math.max(1, math.floor(num(max, 80)))
	if #text > max then text = string.sub(text, 1, max) end
	return text
end

------------------------------------------------------------------ the record
local function limitOk(now)
	local minute = math.floor(now / 60)
	if WINDOW.At ~= minute then WINDOW.At, WINDOW.N = minute, 0 end
	if WINDOW.N >= math.max(0, math.floor(num(E.MaxPerMinute, 5))) then return false end
	WINDOW.N += 1
	return true
end

local function anyPlayer()
	for _, p in Players:GetPlayers() do
		if p.Parent == Players then return p end
	end
	return nil
end

local function same(a, b)
	return a.K == b.K and a.S == b.S and a.M == b.M
end

-- one finding: kind "Error" | "Slow", script name, message, value (1 / milliseconds). Returns true when it was logged to
-- analytics (false = over the minute's limit, or nobody to log for)
function ServerErrorService.Record(kind, scriptName, message, value)
	local entry = { T = os.time(), K = kind == "Slow" and "Slow" or "Error", S = ServerErrorService.Clean(scriptName, E.ScriptMax or 40),
		M = ServerErrorService.Clean(message, E.MessageMax or 80), N = 1 }
	local top = RING[1]
	if top and same(top, entry) and entry.T - top.T <= 60 then
		top.N += 1 -- the same finding in a row: one row with a count (its time stays the first one)
		if not table.find(PENDING, top) then table.insert(PENDING, top) end
	else
		table.insert(RING, 1, entry)
		while #RING > math.max(1, math.floor(num(E.Keep, 50))) do table.remove(RING) end
		table.insert(PENDING, entry)
	end
	DIRTY = true
	if not limitOk(os.time()) then return false end
	local t = S and S.TelemetryService
	local p = anyPlayer()
	if p and type(t) == "table" and type(t.Custom) == "function" then
		local ok, err = pcall(t.Custom, p, "ServerError", math.max(1, math.floor(num(value, 1))), entry.S, entry.M, entry.K)
		if not ok then Util.Warn(TAG, "log: " .. tostring(err)) end
		return ok
	end
	return false
end

-- a copy of this server's list (newest first)
function ServerErrorService.Recent()
	local out = {}
	for i, e in RING do out[i] = { T = e.T, K = e.K, S = e.S, M = e.M, N = e.N } end
	return out
end

------------------------------------------------------------------ the saved document
local function store()
	if STORE == nil then
		local base = E.Store or "HaloHorns_Errors_v1"
		local name = Config.StoreName and Config.StoreName(base) or base
		if RunService:IsStudio() then name ..= "_STUDIO" end
		local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
		STORE = ok and st or false
	end
	return STORE or nil
end

-- the merge of two lists (newest first by T, at most Keep, equal rows of the same second kept once)
function ServerErrorService.Merge(old, new)
	local all, seen = {}, {}
	for _, list in { new or {}, old or {} } do
		for _, e in type(list) == "table" and list or {} do
			if type(e) == "table" and type(e.T) == "number" and type(e.S) == "string" and type(e.M) == "string" then
				local key = e.T .. "|" .. e.K .. "|" .. e.S .. "|" .. e.M
				if not seen[key] then
					seen[key] = true
					table.insert(all, { T = e.T, K = e.K == "Slow" and "Slow" or "Error", S = ServerErrorService.Clean(e.S, E.ScriptMax or 40),
						M = ServerErrorService.Clean(e.M, E.MessageMax or 80), N = math.max(1, math.floor(num(e.N, 1))) })
				end
			end
		end
	end
	table.sort(all, function(a, b) return a.T > b.T end)
	while #all > math.max(1, math.floor(num(E.Keep, 50))) do table.remove(all) end
	return all
end

function ServerErrorService.Flush()
	if not DIRTY or #PENDING == 0 then return false end
	local st = store()
	if not st then return false end
	local mine = {}
	for _, e in PENDING do table.insert(mine, e) end
	local ok, err = pcall(st.UpdateAsync, st, "Recent", function(old)
		return ServerErrorService.Merge(old, mine)
	end)
	if ok then
		PENDING = {}
		DIRTY = false
		return true
	end
	Util.Warn(TAG, "save: " .. tostring(err))
	return false
end

-- the saved list: "stored" = this environment's document (Studio: its own copy), "live" = the real game's (read only)
function ServerErrorService.Stored(which)
	local base = E.Store or "HaloHorns_Errors_v1"
	local name = Config.StoreName and Config.StoreName(base) or base
	if which ~= "live" and RunService:IsStudio() then name ..= "_STUDIO" end
	local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
	if not ok then return {}, tostring(st) end
	local okGet, list = pcall(st.GetAsync, st, "Recent")
	if not okGet then return {}, tostring(list) end
	return ServerErrorService.Merge(list, {})
end

-- Studio test aid text: the lines of a list
function ServerErrorService.Text(list)
	local lines = {}
	for i, e in list do
		table.insert(lines, string.format("%d. %s %s %s x%d %s", i, os.date("!%m-%d %H:%M", e.T), e.K, e.S, e.N, e.M))
	end
	return #lines > 0 and table.concat(lines, "\n") or "(no errors)"
end

function ServerErrorService.Debug(which)
	if which == "stored" or which == "live" then
		local list, err = ServerErrorService.Stored(which)
		if err then return "read failed: " .. err end
		return ServerErrorService.Text(list)
	end
	return ServerErrorService.Text(ServerErrorService.Recent())
end

------------------------------------------------------------------ start
function ServerErrorService.Init(registry)
	S = registry
end

function ServerErrorService.Start()
	ScriptContext.Error:Connect(function(message, _trace, scriptInstance)
		local ok, err = pcall(ServerErrorService.Record, "Error", scriptInstance and scriptInstance.Name or "?", message, 1)
		if not ok then Util.Warn(TAG, "record: " .. tostring(err)) end
	end)
	-- a slow tick: one Heartbeat longer than SlowSeconds (the first seconds after the start are ignored: the world builds)
	local startAt = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		if dt > num(E.SlowSeconds, 0.5) and os.clock() - startAt > num(E.SlowIgnoreFirst, 30) then
			pcall(ServerErrorService.Record, "Slow", "Heartbeat", string.format("tick %d ms", math.floor(dt * 1000)), dt * 1000)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(math.max(10, num(E.StoreSeconds, 120)))
			pcall(ServerErrorService.Flush)
		end
	end)
	game:BindToClose(function()
		pcall(ServerErrorService.Flush)
	end)
	print("[ServerErrorService] started")
end

return ServerErrorService
