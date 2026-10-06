-- HalloweenService.luau : the Halloween season (Config.Halloween). The seasonal monster kinds spawn through
-- MonsterService's regular pool (Config.EffectiveMonsterCounts); this service only runs the Pumpkin King miniboss:
-- first FirstDelay s after server start, then every Interval s (counted from the previous appearance) near the meadow
-- center, for at most Lifetime s. Defeated -> every contributor is paid by MonsterService's normal kill path
-- (MonsterKilled once per contributor: XP / gold / war points / LootService drops; nothing extra here) and everyone
-- gets one chat line; not defeated in time -> it leaves with a friendly line. Enabled = false -> no schedule, no HUD.
-- GameState for EventHUD: PumpkinKingNextAt (Util.Now server time of the next appearance, 0 = season off),
-- PumpkinKingActive, PumpkinKingEndsAt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local HalloweenService = {}
local S = nil
local TAG = "HalloweenService"
local H = Config.Halloween or {}
-- Rec = the living king's MonsterService record (nil = none), NextAt / EndsAt = Util.Now() times
local K = { Rec = nil, NextAt = 0, EndsAt = 0, WarnAt = {} }

local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (K.WarnAt[key] or -math.huge) < 10 then return end
	K.WarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function seasonOn()
	return H.Enabled == true
end

-- the miniboss kind id, or nil when Config has none
local function kingKind()
	local id = H.King
	if type(id) == "string" and type(Config.MonsterTypes[id]) == "table" then return id end
	return nil
end

local function setGame(key, value)
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gs:SetAttribute(key, value) end
end

local function publish()
	local active = K.Rec ~= nil
	setGame("PumpkinKingActive", active)
	setGame("PumpkinKingEndsAt", active and K.EndsAt or 0)
	setGame("PumpkinKingNextAt", seasonOn() and K.NextAt or 0)
end

-- one server-wide chat line (Config.Announce.Events key); never blocks the schedule
local function announce(key)
	local svc = S and S.AnnounceService
	if type(svc) ~= "table" or type(svc.Broadcast) ~= "function" then
		warnThrottled("announce", "AnnounceService.Broadcast missing")
		return
	end
	local ok, err = pcall(svc.Broadcast, key)
	if not ok then warnThrottled("announce", "Broadcast " .. tostring(key) .. ": " .. tostring(err)) end
end

-- spawns the king near its zone's center; true when it appeared
local function appear(now)
	local kind = kingKind()
	if not kind or K.Rec ~= nil then return false end
	local svc = S and S.MonsterService
	if type(svc) ~= "table" or type(svc.SpawnEvent) ~= "function" then
		warnThrottled("spawn", "MonsterService.SpawnEvent missing")
		return false
	end
	local zone = Config.Zones[Config.MonsterTypes[kind].Zone]
	local spots = type(H.SpawnSpots) == "table" and H.SpawnSpots or nil
	local near = spots and #spots > 0 and spots[math.random(1, #spots)] or (zone and zone.Center or nil)
	local ok, rec = pcall(svc.SpawnEvent, kind, { Near = near, Radius = num(H.SpawnRadius, 12) })
	if not ok or type(rec) ~= "table" then
		if not ok then warnThrottled("spawn", rec) end
		return false
	end
	K.Rec = rec
	K.EndsAt = now + math.max(1, num(H.Lifetime, 300))
	publish()
	announce("PumpkinKingAppear")
	return true
end

-- the king is gone: defeated (rewards were already paid by MonsterService) or leaving (removed without rewards)
local function finish(defeated)
	local rec = K.Rec
	K.Rec = nil
	K.EndsAt = 0
	if not defeated and type(rec) == "table" and rec.Alive then
		local svc = S and S.MonsterService
		if type(svc) == "table" and type(svc.RemoveEvent) == "function" then
			local ok, err = pcall(svc.RemoveEvent, rec, true, true) -- goes home: floats up and fades, no death splat
			if not ok then warnThrottled("remove", err) end
		end
	end
	publish()
	announce(defeated and "PumpkinKingDefeat" or "PumpkinKingLeave")
end

local function tick()
	local now = Util.Now()
	local interval = math.max(60, num(H.Interval, 1200))
	local rec = K.Rec
	if rec ~= nil then
		if not rec.Alive then
			-- MonsterService's kill sets HP to 0; a lost model (fell out of the world) is removed with its HP left
			finish(num(rec.HP, 1) <= 0)
		elseif now >= K.EndsAt then
			finish(false)
		elseif K.NextAt > 0 and now >= K.NextAt then
			K.NextAt += interval -- a slot that comes while one is still here (Studio debug spawn) is skipped
			publish()
		end
		return
	end
	if not seasonOn() or K.NextAt <= 0 or now < K.NextAt then return end
	if appear(now) then
		K.NextAt = now + interval
	else
		K.NextAt = now + math.max(1, num(H.RetryDelay, 10)) -- no walkable spot this time
	end
	publish()
end

function HalloweenService.Init(registry)
	S = registry
end

function HalloweenService.Start()
	K.NextAt = (seasonOn() and kingKind() ~= nil) and (Util.Now() + math.max(0, num(H.FirstDelay, 360))) or 0
	publish()
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, num(H.Tick, 0.5)))
			local ok, err = pcall(tick)
			if not ok then warnThrottled("tick", err) end
		end
	end)
	print(("[HalloweenService] started (season %s)"):format(seasonOn() and "on" or "off"))
end

function HalloweenService.IsKingActive()
	return K.Rec ~= nil and K.Rec.Alive == true
end

-- Studio test aid (Main DebugCommand "PumpkinKing"): the king appears now (also with the season off); the regular
-- schedule is unchanged
function HalloweenService.DebugSpawn()
	if K.Rec ~= nil then
		if K.Rec.Alive then return "already here" end
		finish(num(K.Rec.HP, 1) <= 0) -- the previous one is gone but the tick has not closed it yet
	end
	if not kingKind() then return "no king kind in Config.Halloween.King" end
	return appear(Util.Now()) and "spawned" or "no walkable spot found (try again)"
end

return HalloweenService
