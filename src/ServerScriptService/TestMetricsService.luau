-- TestMetricsService.luau : A23-160 ④ the private test's numbers board (게임성 개발 2, 2026-10-13; contract
-- docs/design/test_metrics_2026-10-13.md, read with tools/test_metrics_board.py). An observer like HealthService: it changes
-- no game state and adds only data.Telemetry.Test to the save; every handler is pcall'd, no name or UserId is ever stored.
-- Never on the Live game (Config.EnvName() == "Live", 최종 검수 10/13 review), like Config.ApplyTestServer.
-- While Config.TestMetrics.Enabled it sums, per test round (Config.TestMetrics.Round), into ONE DataStore document
-- (Config.StoreName(Config.TestMetrics.Store); Studio: its own "_STUDIO" copy; key = the round):
--   Players (accounts seen this round), New (of them, fresh saves), Joins,
--   Intro / Faction (new accounts that finished the intro / picked a side = the first screen),
--   Min[milestone][minute] (new accounts reaching Lv5 / Lv10 / Weapon (the first weapon: the Forge's tier 1, A23-188) / Claim (the first
--   mission claimed) at that whole minute of play, capped at MaxMinute), Ten (new accounts with Lv5 + Weapon + Claim all
--   before TenMinutes), Side[faction] / Device[device] (a new account's first side / first Perf sample's device),
--   Pass[key] = { Bought, Back (bought, then joined again), Kept (on that later join Roblox said it is owned), Unknown (Roblox
--   had not answered by then: MonetizationService.PassAnswer nil - the saved last answer is never counted as Kept) }.
-- Per account (the save, additive): data.Telemetry.Test = { R = round, N = new, J = joins this round, I / S / D = intro / side /
-- device counted, M = { [milestone] = minute }, T = Ten counted, P = { [pass] = J of the purchase }, K = { [pass] = rejoin counted } }.
-- Every FlushSeconds (x0.5..1.5) and at the close the unsaved sums are MERGED (UpdateAsync, numbers added); a failed write keeps
-- them for the next flush.
--   TestMetricsService.Merge(old, delta) -> document (pure)   .Flush()   .Pending()
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local TestMetricsService = {}

local TAG = "TestMetricsService"
local S = nil
local M = Config.TestMetrics or {}
local X = {
	Delta = {}, -- the unsaved sums
	Store = nil, -- the DataStore (false = could not open)
	Conns = {}, -- [Player] = { RBXScriptConnection }
	Watched = { "IntroSeen", "Faction", "Level", "WeaponOwnedMask", "TutorialStep" },
	Sides = { Halo = true, Horns = true, Neutral = true },
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function sub(t, name)
	if type(t[name]) ~= "table" then t[name] = {} end
	return t[name]
end

local function bump(t, key, n)
	t[key] = num(t[key]) + (n or 1)
end

-- numbers added (tables recursively); anything else from `src` is dropped
local function sumInto(dst, src)
	for k, v in src do
		if type(k) ~= "string" then continue end
		if type(v) == "number" and v == v then
			dst[k] = num(dst[k]) + v
		elseif type(v) == "table" then
			sumInto(sub(dst, k), v)
		end
	end
end

function TestMetricsService.Merge(old, new)
	local out = {}
	if type(old) == "table" then sumInto(out, old) end
	if type(new) == "table" then sumInto(out, new) end
	out.V = 1
	return out
end

function TestMetricsService.Pending()
	return TestMetricsService.Merge(nil, X.Delta)
end

local function store()
	if X.Store == nil then
		local base = M.Store or "HaloHorns_TestMetrics_v1"
		local name = Config.StoreName and Config.StoreName(base) or base
		if RunService:IsStudio() then name ..= "_STUDIO" end
		local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
		X.Store = ok and st or false
	end
	return X.Store or nil
end

-- writes the unsaved sums; true when there was nothing to write or the write worked
function TestMetricsService.Flush()
	if next(X.Delta) == nil then return true end
	local st = store()
	if not st then return false end
	local mine = X.Delta
	X.Delta = {} -- what is added while the write waits goes to the next flush
	local ok, err = pcall(st.UpdateAsync, st, tostring(M.Round or "PT1"), function(old)
		return TestMetricsService.Merge(old, mine)
	end)
	if ok then return true end
	Util.Warn(TAG, "save: " .. tostring(err))
	local back = {}
	sumInto(back, mine)
	sumInto(back, X.Delta)
	X.Delta = back
	return false
end

------------------------------------------------------------------ the account record
local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

-- this round's record (a record of an older round starts over)
local function recordOf(data)
	if type(data.Telemetry) ~= "table" then data.Telemetry = {} end
	local rec = data.Telemetry.Test
	local round = tostring(M.Round or "PT1")
	if type(rec) ~= "table" or rec.R ~= round then
		rec = { R = round, J = 0, M = {}, P = {}, K = {} }
		data.Telemetry.Test = rec
	end
	for _, k in { "M", "P", "K" } do
		if type(rec[k]) ~= "table" then rec[k] = {} end
	end
	return rec
end

local function fresh(player, data)
	return data.IntroSeen ~= true and num(data.Level, 1) <= 1 and num(data.TotalKills) <= 0
		and num(player:GetAttribute("PlaytimeSeconds"), num(data.PlaytimeSeconds)) < num(M.FreshSeconds, 120)
end

local function minuteOf(player, data)
	local sec = num(player:GetAttribute("PlaytimeSeconds"), num(data.PlaytimeSeconds))
	return math.clamp(math.floor(math.max(0, sec) / 60), 0, math.max(1, math.floor(num(M.MaxMinute, 60))))
end

local function attr(player, data, key)
	local v = player:GetAttribute(key)
	if v == nil then v = data[key] end
	return v
end

-- the milestones reached now (Config.TestMetrics.Milestones names)
local REACHED = {
	Lv5 = function(p, d) return num(attr(p, d, "Level"), 1) >= 5 end,
	Lv10 = function(p, d) return num(attr(p, d, "Level"), 1) >= 10 end,
	-- A23-188 (최종 검수 10/14): the first weapon = the Forge's T1 gift (any weapon owned); the first mission is that visit
	Weapon = function(p, d) return num(attr(p, d, "WeaponOwnedMask")) >= 1 end,
	Claim = function(p, d) return num(attr(p, d, "TutorialStep")) == 99 end, -- Config.Tutorial.Steps.Done = claimed
	-- GPT review ④ (10/14): the first dropped weapon (a bit above tier 1: the first Slime Prince's tier 2, or later)
	DropWeapon = function(p, d) return num(attr(p, d, "WeaponOwnedMask")) >= 2 end,
}

-- a new account's first screen, milestones and the 10-minute run, each counted once
local function scan(player)
	local data = getData(player)
	if not data then return end
	local rec = recordOf(data)
	if rec.N ~= true then return end
	local d = X.Delta
	if not rec.I and attr(player, data, "IntroSeen") == true then
		rec.I = true
		bump(d, "Intro")
	end
	local side = attr(player, data, "Faction")
	if not rec.S and type(side) == "string" and X.Sides[side] then
		rec.S = true
		bump(d, "Faction")
		bump(sub(d, "Side"), side)
	end
	for _, m in M.Milestones or {} do
		local reached = REACHED[m]
		if reached and rec.M[m] == nil and reached(player, data) then
			local minute = minuteOf(player, data)
			rec.M[m] = minute
			bump(sub(sub(d, "Min"), m), tostring(minute))
		end
	end
	local ten = num(M.TenMinutes, 10)
	local mm = rec.M
	if not rec.T and mm.Lv5 ~= nil and mm.Weapon ~= nil and mm.Claim ~= nil
		and mm.Lv5 < ten and mm.Weapon < ten and mm.Claim < ten then
		rec.T = true
		bump(d, "Ten")
	end
end

local function passKey(key)
	if type(key) ~= "string" then return nil end
	if type(Config.GamePasses) == "table" and Config.GamePasses[key] then return key end
	if type(Config.Looks) == "table" and type(Config.Looks[key]) == "table" then return key end
	return nil
end

-- a pass bought on an earlier join: is it still working on this one (after the join's ownership check)?
local function checkKept(player, key)
	if player.Parent == nil then return end
	local data = getData(player)
	if not data then return end
	local rec = recordOf(data)
	if rec.K[key] then return end
	rec.K[key] = true
	-- 최종 검수 10/13 review: Roblox's own answer of this session only (PassAnswer: true / false, nil = not answered yet);
	-- HasPass would also return the saved last answer (PASS.Seen), which proves nothing about this join
	local mon = S.MonetizationService
	local ok, answer = false, nil
	if type(mon) == "table" and type(mon.PassAnswer) == "function" then ok, answer = pcall(mon.PassAnswer, player, key) end
	local p = sub(sub(X.Delta, "Pass"), key)
	bump(p, "Back")
	if ok and answer == true then
		bump(p, "Kept")
	elseif not ok or answer == nil then
		bump(p, "Unknown")
	end
end

function TestMetricsService.OnJoin(player, data)
	data = type(data) == "table" and data or getData(player)
	if not data then return end
	local rec = recordOf(data)
	local d = X.Delta
	if num(rec.J) == 0 then
		bump(d, "Players")
		rec.N = fresh(player, data)
		if rec.N then bump(d, "New") end
	end
	rec.J = math.floor(num(rec.J)) + 1
	bump(d, "Joins")
	for key, at in rec.P do
		if passKey(key) and not rec.K[key] and rec.J > num(at) then
			task.delay(math.max(1, num(M.KeptDelay, 20)), function()
				local ok, err = pcall(checkKept, player, key)
				if not ok then Util.Warn(TAG, "kept: " .. tostring(err)) end
			end)
		end
	end
	for _, c in X.Conns[player] or {} do c:Disconnect() end
	local conns = {}
	X.Conns[player] = conns
	for _, a in X.Watched do
		table.insert(conns, player:GetAttributeChangedSignal(a):Connect(function()
			local ok, err = pcall(scan, player)
			if not ok then Util.Warn(TAG, "scan: " .. tostring(err)) end
		end))
	end
	scan(player)
end

function TestMetricsService.OnLeave(player)
	for _, c in X.Conns[player] or {} do c:Disconnect() end
	X.Conns[player] = nil
end

-- Codex B6 (최종 검수 10/14): a new account's XP by source (hunting = a kill's XP, everything else = quests / dailies /
-- boards ...) up to Lv10, added to XP[Lv5 / Lv10] = { Hunt, Other, N } once when the account reaches that level (the
-- level-up grant included: it is counted before the level is looked at). Per account: rec.X = { H, O, Done }
function TestMetricsService.OnXP(player, amount, source)
	local data = getData(player)
	if not data then return end
	local rec = recordOf(data)
	if rec.N ~= true then return end
	local n = math.max(0, math.floor(num(amount)))
	if n <= 0 then return end
	if type(rec.X) ~= "table" then rec.X = { H = 0, O = 0, Done = {} } end
	local x = rec.X
	if type(x.Done) ~= "table" then x.Done = {} end
	if not x.Done.Lv10 then
		if source == "Monster" then x.H = num(x.H) + n else x.O = num(x.O) + n end
	end
	for _, m in { "Lv5", "Lv10" } do
		if not x.Done[m] and REACHED[m](player, data) then
			x.Done[m] = true
			local row = sub(sub(X.Delta, "XP"), m)
			bump(row, "Hunt", num(x.H))
			bump(row, "Other", num(x.O))
			bump(row, "N", 1)
		end
	end
end

function TestMetricsService.OnPassBought(player, key)
	key = passKey(key)
	local data = key and getData(player)
	if not data then return end
	local rec = recordOf(data)
	if rec.P[key] == nil then rec.P[key] = math.max(1, math.floor(num(rec.J))) end
	bump(sub(sub(X.Delta, "Pass"), key), "Bought")
end

function TestMetricsService.OnClientMetric(player, id, arg)
	if id ~= "Perf" or type(arg) ~= "table" then return end
	local data = getData(player)
	if not data then return end
	local rec = recordOf(data)
	local dev = arg.D
	if rec.N ~= true or rec.D or type(dev) ~= "string" then return end
	local devices = Config.Analytics and Config.Analytics.PerfDevices or {}
	if not table.find(devices, dev) then return end
	rec.D = true
	bump(sub(X.Delta, "Device"), dev)
end

------------------------------------------------------------------ start
local function connect(service, signal, fn)
	local svc = S[service]
	local sig = svc and svc[signal]
	if type(sig) == "table" and type(sig.Connect) == "function" then
		sig:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn(TAG, service .. "." .. signal .. ": " .. tostring(err)) end
		end)
	end
end

function TestMetricsService.Init(registry)
	S = registry
end

function TestMetricsService.Start()
	if M.Enabled ~= true then return end
	if type(Config.EnvName) == "function" and Config.EnvName() == "Live" then return end -- never on the Live game
	connect("PlayerService", "PlayerReady", TestMetricsService.OnJoin)
	connect("PlayerService", "PlayerLeaving", TestMetricsService.OnLeave)
	connect("MonetizationService", "PassBought", TestMetricsService.OnPassBought)
	connect("ProgressionService", "XPEarned", TestMetricsService.OnXP) -- Codex B6
	connect("TelemetryService", "ClientMetric", TestMetricsService.OnClientMetric)
	task.spawn(function()
		local every = math.max(30, num(M.FlushSeconds, 60))
		while true do
			task.wait(every * (0.5 + Util.Random:NextNumber())) -- servers do not all write in the same second
			pcall(TestMetricsService.Flush)
		end
	end)
	game:BindToClose(function()
		pcall(TestMetricsService.Flush)
	end)
	print("[TestMetricsService] started")
end

return TestMetricsService
