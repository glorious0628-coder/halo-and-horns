-- SlimeKingService.luau : the King Slime boss (게임성 개발 2, 2026-10-08; docs/design/king_slime_split_2026-10-08.md §3,
-- 검수 OK, user "네모난 킹 슬라임을 하나 만들자" + "저기 왕관처럼 있는 돌 성 앞에서 나오게 해 줘"). Config.SlimeKing: at most
-- one on the server. The first slot comes FirstDelay s after the start, then every Interval s counted from its last
-- appearance; a slot that comes while nobody ready is in its zone (the meadow) waits for the first one there. It stays
-- Lifetime s. Spot (SPOT.Find), first that exists: an instance under workspace.Map with a Vector3 attribute KingSpawn
-- (the crown-rock shrine on King Slime Hill, put there by 검수's tool), ServerStorage.MeadowTerrainStore's HillTop moved
-- PathStep studs toward its HillPathFoot (the dirt path), Config.SlimeKing.Spawn. MonsterService.SpawnEvent puts it on
-- walkable ground within Radius of the spot. Defeated: MonsterService's normal kill pays every eligible contributor
-- (the def's A23-27 rules: RewardMinHits / RewardMinDamageFrac / XPCapBelowLevel; the boss leaves new players alone:
-- Config.Halloween SafeBelowLevel / SafePlaySeconds), FinisherService gives the card, Fx "KingDefeat" { Key, Kind, Pos,
-- Contributors } to everyone (the defeat sound, as the Halloween kings) and the chat line <Key>Defeat; time up: it goes
-- home (RemoveEvent fade, leaving) with <Key>Leave. Chat lines: AnnounceService.Broadcast <Key>Appear / Defeat / Leave.
-- GameState: <Key>Active, <Key>EndsAt (Util.Now time it leaves, 0 = none), <Key>NextAt (Util.Now time of the next
-- slot; a past time = due, waiting for a hunter in the meadow; 0 = off). Signal Defeated(kind, { UserIds paid }).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local SlimeKingService = {}
SlimeKingService.Defeated = Util.Signal.new() -- (kind, { UserIds the kill paid })

local TAG = "SlimeKingService"
local S = nil
local C = Config.SlimeKing or {}
-- B = the boss: Rec (living MonsterService record or nil), NextAt / EndsAt (Util.Now times), Defeats (this server)
local B = { Rec = nil, NextAt = 0, EndsAt = 0, WarnAt = {}, Defeats = 0 }
local SPOT = {}

local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (B.WarnAt[key] or -math.huge) < 10 then return end
	B.WarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function key()
	return type(C.Key) == "string" and C.Key or "SlimeKing"
end

local function kind()
	return type(C.Kind) == "string" and C.Kind or "SlimeKing"
end

local function setGame(k, value)
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gs:SetAttribute(k, value) end
end

local function publish()
	local active = B.Rec ~= nil
	setGame(key() .. "Active", active)
	setGame(key() .. "EndsAt", active and B.EndsAt or 0)
	setGame(key() .. "NextAt", C.Enabled ~= false and B.NextAt or 0)
end

local function announce(k, args)
	local svc = S and S.AnnounceService
	if type(svc) ~= "table" or type(svc.Broadcast) ~= "function" then
		warnThrottled("announce", "AnnounceService.Broadcast missing")
		return
	end
	local ok, err = pcall(svc.Broadcast, k, args)
	if not ok then warnThrottled("announce", "Broadcast " .. tostring(k) .. ": " .. tostring(err)) end
end

------------------------------------------------------------------ the spot
-- the shrine's KingSpawn (a Vector3 attribute on any instance under workspace.Map; the first one found)
function SPOT.Shrine()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	for _, d in map:GetDescendants() do
		local v = d:GetAttribute("KingSpawn")
		if typeof(v) == "Vector3" then return v end
	end
	return nil
end

-- the hill top moved PathStep studs toward the path foot (flat), from the meadow terrain store
function SPOT.Hill()
	local store = ServerStorage:FindFirstChild("MeadowTerrainStore")
	local top = store and store:GetAttribute("HillTop")
	if typeof(top) ~= "Vector3" then return nil end
	local foot = store:GetAttribute("HillPathFoot")
	if typeof(foot) ~= "Vector3" then return top end
	local d = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)
	if d.Magnitude < 0.01 then return top end
	return top + d.Unit * math.max(0, num(C.PathStep, 8))
end

function SPOT.Find()
	local okS, shrine = pcall(SPOT.Shrine)
	if okS and shrine then return shrine, "Shrine" end
	local okH, hill = pcall(SPOT.Hill)
	if okH and hill then return hill, "Hill" end
	if typeof(C.Spawn) == "Vector3" then return C.Spawn, "Config" end
	return nil, nil
end

-- true when a ready player stands in the boss's zone
local function hunterHere()
	local zone = Config.MonsterTypes[kind()] and Config.MonsterTypes[kind()].Zone
	for _, p in Players:GetPlayers() do
		if S.PlayerService.IsReady(p) then
			local ok, z = pcall(S.ZoneService.GetZoneId, p)
			if ok and z == zone then return true end
		end
	end
	return false
end

------------------------------------------------------------------ appear / finish
-- spawns the boss at its spot; true when it appeared
local function appear(now)
	if B.Rec ~= nil then return false end
	local svc = S and S.MonsterService
	if type(svc) ~= "table" or type(svc.SpawnEvent) ~= "function" then
		warnThrottled("spawn", "MonsterService.SpawnEvent missing")
		return false
	end
	local near = SPOT.Find()
	local ok, rec = pcall(svc.SpawnEvent, kind(), { Near = near, Radius = math.max(0, num(C.Radius, 2)) })
	if not ok or type(rec) ~= "table" then
		if not ok then warnThrottled("spawn", rec) end
		return false
	end
	B.Rec, B.EndsAt = rec, now + math.max(1, num(C.Lifetime, 300))
	publish()
	announce(key() .. "Appear")
	return true
end

-- the boss is gone: defeated (MonsterService already paid) or leaving (removed without rewards)
local function finish(defeated)
	local rec = B.Rec
	B.Rec, B.EndsAt = nil, 0
	if not defeated and type(rec) == "table" and rec.Alive then
		local svc = S and S.MonsterService
		if type(svc) == "table" and type(svc.RemoveEvent) == "function" then
			local ok, err = pcall(svc.RemoveEvent, rec, true, true) -- goes home: floats up and fades, no splat
			if not ok then warnThrottled("remove", err) end
		end
	end
	publish()
	if defeated and type(rec) == "table" then
		B.Defeats += 1
		local ids = {}
		for _, id in type(rec.PaidUserIds) == "table" and rec.PaidUserIds or {} do
			if type(id) == "number" then table.insert(ids, id) end
		end
		local root = rec.Root
		local ok, err = pcall(Net.Fx, nil, "KingDefeat", { Key = key(), Kind = rec.Kind,
			Pos = root and typeof(root.Position) == "Vector3" and root.Position or nil, Contributors = ids })
		if not ok then warnThrottled("defeat", err) end
		SlimeKingService.Defeated:Fire(rec.Kind, table.clone(ids))
	end
	announce(key() .. (defeated and "Defeat" or "Leave"))
end

local function tick()
	local now = Util.Now()
	local rec = B.Rec
	if rec ~= nil then
		if not rec.Alive then
			finish(num(rec.HP, 1) <= 0) -- a lost model (fell out of the world) keeps its HP: not a defeat
		elseif now >= B.EndsAt then
			finish(false)
		elseif B.NextAt > 0 and now >= B.NextAt then
			B.NextAt += math.max(60, num(C.Interval, 480)) -- a slot while one is still here (a Studio spawn) is skipped
			publish()
		end
		return
	end
	if C.Enabled == false or B.NextAt <= 0 or now < B.NextAt then return end
	if not hunterHere() then return end -- due: waits for a hunter in the meadow (NextAt stays in the past)
	if appear(now) then
		B.NextAt = now + math.max(60, num(C.Interval, 480))
	else
		B.NextAt = now + math.max(1, num(C.RetryDelay, 10)) -- no walkable ground this time
	end
	publish()
end

------------------------------------------------------------------ public
function SlimeKingService.IsActive()
	return B.Rec ~= nil and B.Rec.Alive == true
end

-- Studio test aid (Main DebugCommand "SlimeKing"): it appears now (the regular schedule is unchanged)
function SlimeKingService.DebugSpawn()
	if B.Rec ~= nil then
		if B.Rec.Alive then return "already here" end
		finish(num(B.Rec.HP, 1) <= 0)
	end
	local ok = appear(Util.Now())
	return ok and "spawned" or "no walkable spot found (try again)"
end

function SlimeKingService.Init(registry)
	S = registry
end

function SlimeKingService.Start()
	if type(Config.MonsterTypes[kind()]) ~= "table" then
		Util.Warn(TAG, "Config.MonsterTypes." .. kind() .. " missing: no boss")
		return
	end
	B.NextAt = C.Enabled ~= false and (Util.Now() + math.max(0, num(C.FirstDelay, 180))) or 0
	publish()
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, num(C.Tick, 0.5)))
			local ok, err = pcall(tick)
			if not ok then warnThrottled("tick", err) end
		end
	end)
	print(("[SlimeKingService] started (first in %ds)"):format(math.floor(math.max(0, num(C.FirstDelay, 180)))))
end

return SlimeKingService
