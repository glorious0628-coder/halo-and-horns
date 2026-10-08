-- HalloweenService.luau : the Halloween season (Config.Halloween). The seasonal monster kinds spawn through
-- MonsterService's regular pool (Config.EffectiveMonsterCounts), one family per field (A23-45): pumpkins in the
-- PumpkinPatch, bat goblins in the GoblinWoods, ghosts in the HauntedHollow. This service runs the minibosses of
-- Config.Halloween.Bosses (the Pumpkin King, then the Ghost King 10 minutes later): each first FirstDelay s after server
-- start, then every Interval s (counted from its previous appearance) at one of its SpawnSpots, for at most Lifetime s.
-- Defeated -> every ELIGIBLE contributor is paid by MonsterService's normal kill path (A23-27: own hits >=
-- RewardMinHits and damage >= RewardMinDamageFrac of MaxHP; MonsterKilled once each: XP / gold / war points /
-- LootService drops; nothing extra here) and everyone gets one chat line; not defeated in time -> it leaves with a
-- friendly line. A boss never targets a player below SafeBelowLevel or with less than SafePlaySeconds played
-- (MonsterService.targetable). Season off (Enabled = false, or past EndsAt: A23-28 HW-13, checked every tick) -> no
-- schedule, no HUD line, a boss that is still here leaves, and the PumpkinPatch road sign (MapBuilder) is hidden.
-- GameState for EventHUD, per boss Key: <Key>NextAt (Util.Now server time of the next appearance, 0 = season off),
-- <Key>Active, <Key>EndsAt (PumpkinKing*, GhostKing*).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local HalloweenService = {}
-- A23-79 (게임성 개발 3): a king beaten (not one that left): (Key, Kind, { UserIds the kill paid }) - the King Diary
HalloweenService.KingDefeated = Util.Signal.new()
local S = nil
local TAG = "HalloweenService"
local H = Config.Halloween or {}
-- BOSSES[i] = { Kind, Key, FirstDelay, Interval, Lifetime, Spots, Rec (living MonsterService record or nil),
--   NextAt / EndsAt (Util.Now() times), Debug }
local BOSSES = {}
-- Defeats = kings beaten on this server since it started (memory only: the ⑫ Day 9 line)
local K = { WarnAt = {}, SignOn = nil, Defeats = 0 }

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

-- Enabled and before Config.Halloween.EndsAt (Config.SeasonOn reads the server clock)
local function seasonOn()
	return Config.SeasonOn("Halloween")
end

-- the PumpkinPatch road sign (MapBuilder: Map.Landmarks.PumpkinPatchSign) shows only while the season is on
local function showSign(on)
	if K.SignOn == on then return end
	local map = workspace:FindFirstChild("Map")
	local lm = map and map:FindFirstChild("Landmarks")
	local sign = lm and lm:FindFirstChild("PumpkinPatchSign")
	if not sign then return end -- MapBuilder has not built it yet: try again next tick
	K.SignOn = on
	for _, d in sign:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = on and (d:GetAttribute("ShownTransparency") or 0) or 1
			d.CanCollide = on and d:GetAttribute("ShownCollide") == true
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			d.Enabled = on
		end
	end
end

-- Config.Halloween.Bosses (A23-45), or the single legacy King; kinds missing from Config.MonsterTypes are skipped
local function buildBosses()
	table.clear(BOSSES)
	local list = type(H.Bosses) == "table" and H.Bosses or { { Kind = H.King, Key = "PumpkinKing" } }
	for _, e in list do
		local kind = type(e) == "table" and e.Kind or nil
		if type(kind) == "string" and type(Config.MonsterTypes[kind]) == "table" then
			table.insert(BOSSES, {
				Kind = kind,
				Key = type(e.Key) == "string" and e.Key or kind,
				FirstDelay = num(e.FirstDelay, num(H.FirstDelay, 360)),
				Interval = math.max(60, num(e.Interval, num(H.Interval, 1200))),
				Lifetime = math.max(1, num(e.Lifetime, num(H.Lifetime, 300))),
				Spots = type(e.SpawnSpots) == "table" and e.SpawnSpots or (type(H.SpawnSpots) == "table" and H.SpawnSpots or nil),
				Rec = nil, NextAt = 0, EndsAt = 0, Debug = nil,
			})
		end
	end
end

local function bossOf(kind)
	for _, b in BOSSES do
		if b.Kind == kind then return b end
	end
	return nil
end

local function setGame(key, value)
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gs:SetAttribute(key, value) end
end

local function publish(b)
	local active = b.Rec ~= nil
	setGame(b.Key .. "Active", active)
	setGame(b.Key .. "EndsAt", active and b.EndsAt or 0)
	setGame(b.Key .. "NextAt", seasonOn() and b.NextAt or 0)
end

-- one server-wide chat line (Config.Announce.Events key, optional args); never blocks the schedule
local function announce(key, args)
	local svc = S and S.AnnounceService
	if type(svc) ~= "table" or type(svc.Broadcast) ~= "function" then
		warnThrottled("announce", "AnnounceService.Broadcast missing")
		return
	end
	local ok, err = pcall(svc.Broadcast, key, args)
	if not ok then warnThrottled("announce", "Broadcast " .. tostring(key) .. ": " .. tostring(err)) end
end

-- ⑫ (lines_pack §4): today's banter line of this king, by KST day (Config.Halloween.Banter; Day 1 = 2026-10-31,
-- clamped to the listed days, so a test server before the season shows Day 1). The one "%d" line (Day 9) is filled
-- with this server's beaten kings FIRST (none -> <Key>Zero), then the line goes into Format with the king's Short name.
local function banterLine(b)
	local B = H.Banter
	if type(B) ~= "table" or type(B.Days) ~= "table" or #B.Days == 0 then return nil end
	local day = math.clamp(math.floor((Config.SeasonNow() - num(B.DayOneStart)) / 86400) + 1, 1, #B.Days)
	local line = type(B.Days[day]) == "table" and B.Days[day][b.Key] or nil
	if type(line) ~= "string" or line == "" then return nil end
	if string.find(line, "%d", 1, true) then
		local zero = B[b.Key .. "Zero"]
		line = (K.Defeats <= 0 and type(zero) == "string") and zero or string.format(line, K.Defeats)
	end
	local m = Config.MonsterTypes[b.Kind]
	return string.format(type(B.Format) == "string" and B.Format or "%s: \"%s\"", (m and (m.Short or m.Name)) or b.Kind, line)
end

-- spawns the boss at one of its spots (or its zone's center); true when it appeared
local function appear(b, now)
	if b.Rec ~= nil then return false end
	local svc = S and S.MonsterService
	if type(svc) ~= "table" or type(svc.SpawnEvent) ~= "function" then
		warnThrottled("spawn", "MonsterService.SpawnEvent missing")
		return false
	end
	local zone = Config.Zones[Config.MonsterTypes[b.Kind].Zone]
	local spots = b.Spots
	local near = spots and #spots > 0 and spots[math.random(1, #spots)] or (zone and zone.Center or nil)
	local ok, rec = pcall(svc.SpawnEvent, b.Kind, { Near = near, Radius = num(H.SpawnRadius, 12) })
	if not ok or type(rec) ~= "table" then
		if not ok then warnThrottled("spawn" .. b.Kind, rec) end
		return false
	end
	b.Rec = rec
	b.EndsAt = now + b.Lifetime
	publish(b)
	local okLine, line = pcall(banterLine, b)
	if not okLine then warnThrottled("banter", line) end
	announce(b.Key .. "Appear", { Banter = okLine and line or nil }) -- ⑫: the next chat line (Announce, game dev 1)
	return true
end

-- the boss is gone: defeated (rewards were already paid by MonsterService) or leaving (removed without rewards)
local function finish(b, defeated)
	local rec = b.Rec
	b.Rec = nil
	b.EndsAt = 0
	b.Debug = nil
	if not defeated and type(rec) == "table" and rec.Alive then
		local svc = S and S.MonsterService
		if type(svc) == "table" and type(svc.RemoveEvent) == "function" then
			local ok, err = pcall(svc.RemoveEvent, rec, true, true) -- goes home: floats up and fades, no death splat
			if not ok then warnThrottled("remove", err) end
		end
	end
	publish(b)
	if defeated then K.Defeats += 1 end -- ⑫ Day 9: "Kings beaten on this server: %d"
	-- sound_gaps B11: a king beaten (not one that leaves) = Fx "KingDefeat" for everyone: Key / Kind, Pos (nil when the
	-- body is gone) and Contributors = the UserIds the kill paid (their sound is louder, their own kill pop and coins
	-- 0.25 s later). 검수 2026-10-07: MonsterService's kill keeps them on the record (PaidUserIds, sorted) before it
	-- clears the contributor tables, which this runs after
	if defeated and type(rec) == "table" then
		local ids = {}
		for _, id in type(rec.PaidUserIds) == "table" and rec.PaidUserIds or {} do
			if type(id) == "number" then table.insert(ids, id) end
		end
		local root = rec.Root
		local ok, err = pcall(Net.Fx, nil, "KingDefeat", { Key = b.Key, Kind = rec.Kind,
			Pos = root and typeof(root.Position) == "Vector3" and root.Position or nil, Contributors = ids })
		if not ok then warnThrottled("defeat", err) end
		HalloweenService.KingDefeated:Fire(b.Key, rec.Kind, table.clone(ids))
	end
	announce(b.Key .. (defeated and "Defeat" or "Leave"))
end

local function tickBoss(b, now, on)
	if not on and b.NextAt > 0 then
		b.NextAt = 0 -- the season just ended (HW-13): no more appearances, the HUD line goes away
		publish(b)
	end
	local rec = b.Rec
	if rec ~= nil then
		if not rec.Alive then
			-- MonsterService's kill sets HP to 0; a lost model (fell out of the world) is removed with its HP left
			finish(b, num(rec.HP, 1) <= 0)
		elseif now >= b.EndsAt or (not on and not b.Debug) then
			finish(b, false)
		elseif b.NextAt > 0 and now >= b.NextAt then
			b.NextAt += b.Interval -- a slot that comes while one is still here (Studio debug spawn) is skipped
			publish(b)
		end
		return
	end
	if not on or b.NextAt <= 0 or now < b.NextAt then return end
	if appear(b, now) then
		b.NextAt = now + b.Interval
	else
		b.NextAt = now + math.max(1, num(H.RetryDelay, 10)) -- no walkable spot this time
	end
	publish(b)
end

local function tick()
	local now = Util.Now()
	local on = seasonOn()
	showSign(on)
	for _, b in BOSSES do
		local ok, err = pcall(tickBoss, b, now, on)
		if not ok then warnThrottled("tick" .. b.Kind, err) end
	end
end

function HalloweenService.Init(registry)
	S = registry
end

function HalloweenService.Start()
	buildBosses()
	local now, on = Util.Now(), seasonOn()
	for _, b in BOSSES do
		b.NextAt = on and (now + math.max(0, b.FirstDelay)) or 0
		publish(b)
	end
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, num(H.Tick, 0.5)))
			local ok, err = pcall(tick)
			if not ok then warnThrottled("tick", err) end
		end
	end)
	print(("[HalloweenService] started (season %s, %d bosses)"):format(on and "on" or "off", #BOSSES))
end

-- true while any miniboss (or the given kind) is alive
function HalloweenService.IsKingActive(kind)
	for _, b in BOSSES do
		if (kind == nil or b.Kind == kind) and b.Rec ~= nil and b.Rec.Alive == true then return true end
	end
	return false
end

-- Studio test aid (Main DebugCommand "PumpkinKing" / "GhostKing"): that boss appears now; its regular schedule is
-- unchanged. It needs the season on: with it off Config.ZoneAt skips the seasonal fields, so there is no boss ground
function HalloweenService.DebugSpawn(kind)
	local b = bossOf(kind or (BOSSES[1] and BOSSES[1].Kind))
	if not b then return "no such boss in Config.Halloween.Bosses: " .. tostring(kind) end
	if b.Rec ~= nil then
		if b.Rec.Alive then return "already here" end
		finish(b, num(b.Rec.HP, 1) <= 0) -- the previous one is gone but the tick has not closed it yet
	end
	local ok = appear(b, Util.Now())
	b.Debug = ok and not seasonOn() or nil -- a Studio boss with the season off stays its Lifetime
	return ok and "spawned" or "no walkable spot found (try again)"
end

return HalloweenService
