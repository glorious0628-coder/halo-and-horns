-- FieldBossService.luau : the year-round field bosses (게임성 개발 2; content_beyond_10min_2026-10-08 FB, started as
-- SlimeKingService 2026-10-08 for A23-84). Config.FieldBosses: Order = the boss keys, [key] = one boss (Kind, Enabled,
-- FirstDelay, Interval, Lifetime, Radius, RetryDelay, Attr, Hill, PathStep, Spawn, MinLevel). No season: they stay after
-- the Halloween kings leave. At most one of each on the server. The first slot comes FirstDelay s after the start, then
-- every Interval s counted from its last appearance; a slot that comes while nobody ready is in its zone waits for the
-- first one there. It stays Lifetime s. Spot (SPOT.Find), first that exists: an instance under workspace.Map with the
-- Vector3 attribute <Attr> (the King Slime's crown-rock shrine: KingSpawn, put there by 검수's tool), then (Hill = true)
-- ServerStorage.MeadowTerrainStore's HillTop moved PathStep studs toward its HillPathFoot, then Spawn; none = a normal
-- spawn point of the zone (MonsterService.SpawnEvent without Near). Defeated: MonsterService's normal kill pays every
-- eligible contributor (the def's A23-27 rules; bosses leave new players alone: Config.Halloween SafeBelowLevel /
-- SafePlaySeconds), FinisherService gives the card, Fx "KingDefeat" { Key, Kind, Pos, Contributors } to everyone and the
-- chat line <Key>Defeat; time up: it goes home (RemoveEvent fade, leaving) with <Key>Leave. Chat lines:
-- AnnounceService.Broadcast <Key>Appear / Defeat / Leave. GameState per boss: <Key>Active, <Key>EndsAt (Util.Now time it
-- leaves, 0 = none), <Key>NextAt (Util.Now time of the next slot; a past time = due, waiting for a hunter; 0 = off).
-- Signal Defeated(key, kind, { UserIds paid }, rec).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local FieldBossService = {}
FieldBossService.Defeated = Util.Signal.new() -- (key, kind, { UserIds the kill paid }, rec)

local TAG = "FieldBossService"
local S = nil
local FB = Config.FieldBosses or {}
-- B[key] = { Rec (living MonsterService record or nil), NextAt / EndsAt (Util.Now times), Defeats (this server) }
local B = {}
local WarnAt = {}
local SPOT = {}

local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (WarnAt[key] or -math.huge) < 10 then return end
	WarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function cfg(key)
	local c = FB[key]
	return type(c) == "table" and c or {}
end

local function kindOf(key)
	local c = cfg(key)
	return type(c.Kind) == "string" and c.Kind or key
end

local function setGame(k, value)
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gs:SetAttribute(k, value) end
end

local function publish(key)
	local b = B[key]
	local active = b.Rec ~= nil
	setGame(key .. "Active", active)
	setGame(key .. "EndsAt", active and b.EndsAt or 0)
	setGame(key .. "NextAt", cfg(key).Enabled ~= false and b.NextAt or 0)
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
-- the first Vector3 attribute `attr` on an instance under workspace.Map
function SPOT.Marked(attr)
	if type(attr) ~= "string" then return nil end
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	for _, d in map:GetDescendants() do
		local v = d:GetAttribute(attr)
		if typeof(v) == "Vector3" then return v end
	end
	return nil
end

-- the meadow hill top moved `step` studs toward the path foot (flat), from the meadow terrain store
function SPOT.Hill(step)
	local store = ServerStorage:FindFirstChild("MeadowTerrainStore")
	local top = store and store:GetAttribute("HillTop")
	if typeof(top) ~= "Vector3" then return nil end
	local foot = store:GetAttribute("HillPathFoot")
	if typeof(foot) ~= "Vector3" then return top end
	local d = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)
	if d.Magnitude < 0.01 then return top end
	return top + d.Unit * math.max(0, num(step, 8))
end

function SPOT.Find(key)
	local c = cfg(key)
	local okS, marked = pcall(SPOT.Marked, c.Attr)
	if okS and marked then return marked, "Marked" end
	if c.Hill == true then
		local okH, hill = pcall(SPOT.Hill, c.PathStep)
		if okH and hill then return hill, "Hill" end
	end
	if typeof(c.Spawn) == "Vector3" then return c.Spawn, "Config" end
	return nil, nil
end

-- true when a ready player stands in the boss's zone
local function hunterHere(key)
	local def = Config.MonsterTypes[kindOf(key)]
	local zone = def and def.Zone
	for _, p in Players:GetPlayers() do
		if S.PlayerService.IsReady(p) then
			local ok, z = pcall(S.ZoneService.GetZoneId, p)
			if ok and z == zone then return true end
		end
	end
	return false
end

------------------------------------------------------------------ defeat extras (J: Captain Clatter)
-- the side share of the boss's damage (MonsterService rec.FactionDamage): { Halo = %, Horns = % } (whole numbers that
-- add up to 100), nil when no side hit it
local function shareOf(rec)
	local d = type(rec.FactionDamage) == "table" and rec.FactionDamage or {}
	local h, r = math.max(0, num(d.Halo)), math.max(0, num(d.Horns))
	if h + r <= 0 then return nil end
	local hp = math.floor(h * 100 / (h + r) + 0.5)
	return { Halo = hp, Horns = 100 - hp }
end

-- one paid contributor's extras (Config.FieldBosses[key]): War points for the own side (WarService.AddPoints: None /
-- Neutral get none), Kills +1 and the Titles it reaches, the Weekly item (data.FieldBoss[key] = { Kills, Week, Owed }:
-- the first kill opens a week's guarantee, every later week adds one, banked up to Max; a kill takes one)
-- sides = { [faction] = paid contributors of that side here }: War is each one's personal points, but one kill adds
-- War to a side's pool only once (CR-M18: poolN = War / that side's contributors; 검수 2026-10-09)
local function extraOne(key, c, player, sides)
	if num(c.War) > 0 and S.WarService and type(S.WarService.AddPoints) == "function" then
		local war = math.floor(num(c.War))
		local n = math.max(1, (sides or {})[player:GetAttribute("Faction")] or 1)
		local ok, err = pcall(S.WarService.AddPoints, player, war, war / n)
		if not ok then warnThrottled("war", err) end
	end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	if type(data.FieldBoss) ~= "table" then data.FieldBoss = {} end
	local row = data.FieldBoss[key]
	if type(row) ~= "table" then
		row = {}
		data.FieldBoss[key] = row
	end
	row.Kills = math.max(0, math.floor(num(row.Kills))) + 1
	row.Week = math.max(0, math.floor(num(row.Week)))
	row.Owed = math.max(0, math.floor(num(row.Owed)))
	if type(c.Titles) == "table" and S.TitleService and type(S.TitleService.Grant) == "function" then
		for at, id in c.Titles do
			if type(at) == "number" and row.Kills >= at then
				local ok, err = pcall(S.TitleService.Grant, player, id)
				if not ok then warnThrottled("title", err) end
			end
		end
	end
	local W = c.Weekly
	if type(W) ~= "table" or type(W.Item) ~= "string" then return end
	local max = math.max(1, math.floor(num(W.Max, 1)))
	local week = Config.WeekIndex(os.time())
	if row.Week <= 0 then
		row.Owed = math.min(max, row.Owed + 1)
	elseif week > row.Week then
		row.Owed = math.min(max, row.Owed + (week - row.Week))
	end
	row.Week = math.max(row.Week, week)
	row.Owed = math.min(max, row.Owed) -- a broken save never banks more than Max
	if row.Owed <= 0 then return end
	local n = math.max(1, math.floor(num(W.N, 1)))
	local ok, got = pcall(S.LootService.GrantItem, player, W.Item, n)
	if not ok then
		warnThrottled("weekly", got)
		return
	end
	if num(got) < 1 then return end -- a full bag: the guarantee waits for the next kill
	row.Owed -= 1
	local item = Config.Loot.Items[W.Item]
	local name = item and item.Name or W.Item
	pcall(Net.Notify, player, n > 1 and string.format(Config.Loot.Text.GotN, name, n)
		or string.format(Config.Loot.Text.Got, name), "reward")
end

local function payExtras(key, ids)
	local c = cfg(key)
	local present, sides = {}, {}
	for _, id in ids do
		local p = Players:GetPlayerByUserId(id)
		if p then
			table.insert(present, p)
			local f = p:GetAttribute("Faction")
			if type(f) == "string" then sides[f] = (sides[f] or 0) + 1 end
		end
	end
	for _, p in present do
		local ok, err = pcall(extraOne, key, c, p, sides)
		if not ok then warnThrottled("extra_" .. key, err) end
	end
end

------------------------------------------------------------------ appear / finish
-- spawns the boss at its spot; true when it appeared
local function appear(key, now)
	local b = B[key]
	if b.Rec ~= nil then return false end
	local svc = S and S.MonsterService
	if type(svc) ~= "table" or type(svc.SpawnEvent) ~= "function" then
		warnThrottled("spawn", "MonsterService.SpawnEvent missing")
		return false
	end
	local c = cfg(key)
	local near = SPOT.Find(key)
	local ok, rec = pcall(svc.SpawnEvent, kindOf(key), { Near = near, Radius = math.max(0, num(c.Radius, 2)) })
	if not ok or type(rec) ~= "table" then
		if not ok then warnThrottled("spawn_" .. key, rec) end
		return false
	end
	b.Rec, b.EndsAt = rec, now + math.max(1, num(c.Lifetime, 300))
	publish(key)
	announce(key .. "Appear")
	return true
end

-- the boss is gone: defeated (MonsterService already paid) or leaving (removed without rewards)
local function finish(key, defeated)
	local b = B[key]
	local rec = b.Rec
	b.Rec, b.EndsAt = nil, 0
	if not defeated and type(rec) == "table" and rec.Alive then
		local svc = S and S.MonsterService
		if type(svc) == "table" and type(svc.RemoveEvent) == "function" then
			local ok, err = pcall(svc.RemoveEvent, rec, true, true) -- goes home: floats up and fades, no splat
			if not ok then warnThrottled("remove", err) end
		end
	end
	publish(key)
	if defeated and type(rec) == "table" then
		b.Defeats += 1
		local ids = {}
		for _, id in type(rec.PaidUserIds) == "table" and rec.PaidUserIds or {} do
			if type(id) == "number" then table.insert(ids, id) end
		end
		local root = rec.Root
		local ok, err = pcall(Net.Fx, nil, "KingDefeat", { Key = key, Kind = rec.Kind,
			Pos = root and typeof(root.Position) == "Vector3" and root.Position or nil, Contributors = ids,
			Share = shareOf(rec) })
		if not ok then warnThrottled("defeat", err) end
		payExtras(key, ids)
		FieldBossService.Defeated:Fire(key, rec.Kind, table.clone(ids), rec)
	end
	announce(key .. (defeated and "Defeat" or "Leave"))
end

local function tickOne(key, now)
	local b = B[key]
	local c = cfg(key)
	local rec = b.Rec
	if rec ~= nil then
		if not rec.Alive then
			finish(key, num(rec.HP, 1) <= 0) -- a lost model (fell out of the world) keeps its HP: not a defeat
		elseif now >= b.EndsAt then
			finish(key, false)
		elseif b.NextAt > 0 and now >= b.NextAt then
			b.NextAt += math.max(60, num(c.Interval, 480)) -- a slot while one is still here (a Studio spawn) is skipped
			publish(key)
		end
		return
	end
	if c.Enabled == false or b.NextAt <= 0 or now < b.NextAt then return end
	if not hunterHere(key) then return end -- due: waits for a hunter in its zone (NextAt stays in the past)
	if appear(key, now) then
		b.NextAt = now + math.max(60, num(c.Interval, 480))
	else
		b.NextAt = now + math.max(1, num(c.RetryDelay, 10)) -- no walkable ground this time
	end
	publish(key)
end

------------------------------------------------------------------ public
function FieldBossService.IsActive(key)
	local b = B[key]
	return b ~= nil and b.Rec ~= nil and b.Rec.Alive == true
end

-- Studio test aid (Main DebugCommand "SlimeKing" / "Clatter"): that boss appears now (its schedule is unchanged)
function FieldBossService.DebugSpawn(key)
	local b = B[key]
	if b == nil then return "no field boss " .. tostring(key) end
	if b.Rec ~= nil then
		if b.Rec.Alive then return "already here" end
		finish(key, num(b.Rec.HP, 1) <= 0)
	end
	local ok = appear(key, Util.Now())
	return ok and "spawned" or "no walkable spot found (try again)"
end

function FieldBossService.Init(registry)
	S = registry
end

function FieldBossService.Start()
	local now = Util.Now()
	for _, key in type(FB.Order) == "table" and FB.Order or {} do
		if type(FB[key]) ~= "table" then
			Util.Warn(TAG, "Config.FieldBosses." .. tostring(key) .. " missing")
		elseif type(Config.MonsterTypes[kindOf(key)]) ~= "table" then
			Util.Warn(TAG, "Config.MonsterTypes." .. kindOf(key) .. " missing: no " .. key)
		else
			local c = cfg(key)
			B[key] = { Rec = nil, EndsAt = 0, Defeats = 0,
				NextAt = c.Enabled ~= false and (now + math.max(0, num(c.FirstDelay, 180))) or 0 }
			publish(key)
		end
	end
	task.spawn(function()
		while true do
			task.wait(math.max(0.1, num(FB.Tick, 0.5)))
			local t = Util.Now()
			for _, key in FB.Order or {} do
				if B[key] then
					local ok, err = pcall(tickOne, key, t)
					if not ok then warnThrottled("tick_" .. key, err) end
				end
			end
		end
	end)
	print("[FieldBossService] started")
end

return FieldBossService
