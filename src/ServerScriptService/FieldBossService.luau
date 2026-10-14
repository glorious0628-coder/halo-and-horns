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
-- A23-113 ⑦ crowd HP (Config.FieldBosses.Crowd; a boss's own Crowd table wins, Crowd = false = off): the def HP is one
-- hunter's fight (SoloSeconds, about 2 min); every Every s the hunters are counted - each player's own damage over the
-- last Window s against one hunter's pace (def HP / SoloSeconds) over the time since its first hit there (at least Rise
-- s: a newcomer counts within Rise s, a quitter fades over the window) is that player's share, at most 1, for ready, alive
-- players within Radius studs (flat); hunters = the shares added up, 1..Max - and MaxHP = def HP x (1 + PerHunter x
-- (hunters - 1)), the HP fraction kept (MonsterService.SetEventMaxHP). Bystanders add nothing and a weak hitter (a new
-- player punching the King) adds only its small share; the reward rules stay MonsterService's.
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
-- B[key] = { Rec (living MonsterService record or nil), NextAt / EndsAt (Util.Now times), Defeats (this server),
-- BaseHP (the def HP it came with), Hunters (last count), CrowdAt (Util.Now time of the next count), Snaps (the damage
-- totals at each count still inside the window, oldest first: { At, D = { [Player] = damage } }) }
local B = {}
local WarnAt = {}
local SPOT = {}
local CROWD = {}

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
-- the boss's marked spot under workspace.Map, the first found: a Vector3 attribute `attr` on any instance, or (검수's
-- shrine tool, 2026-10-09) a BasePart named `attr` or with the attribute `attr` = true - its Position
function SPOT.Marked(attr)
	if type(attr) ~= "string" then return nil end
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	local part = nil
	for _, d in map:GetDescendants() do
		local v = d:GetAttribute(attr)
		if typeof(v) == "Vector3" then return v end
		if part == nil and d:IsA("BasePart") and (d.Name == attr or v == true) then part = d end
	end
	return part and part.Position or nil
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

------------------------------------------------------------------ crowd HP (A23-113 ⑦)
-- the boss's crowd rule: its own Crowd table, else Config.FieldBosses.Crowd; nil = off (Crowd = false)
function CROWD.Of(key)
	local own = cfg(key).Crowd
	if own == false then return nil end
	local c = type(own) == "table" and own or FB.Crowd
	return type(c) == "table" and c or nil
end

-- the hunters at the boss now: a snapshot of every player's own damage (MonsterService.DamageTotals) joins b.Snaps; the
-- oldest snapshot still covering the window (c.Window s) is the baseline. A player's share = own damage since the
-- baseline / one hunter's pace (BaseHP / c.SoloSeconds per s) over the time since that player's first hit in the window
-- (the last snapshot before it), at least c.Rise s, at most 1 (c.ByDamage = false: 1 for any damage). So a hunter who
-- comes counts fully within Rise s, one who stops fades over the window (검수 bosshp_verify 2026-10-11: no on / off
-- gain). Only ready, alive players within c.Radius studs of it (flat) count. The shares added up, in tenths, 1..c.Max
-- (nobody yet = one hunter's HP)
function CROWD.Count(b, c, now)
	local rec = b.Rec
	local svc = S.MonsterService
	local pos = rec.Root and rec.Root.Position
	if type(svc.DamageTotals) ~= "function" or typeof(pos) ~= "Vector3" then return 1 end
	local ok, totals = pcall(svc.DamageTotals, rec)
	if not ok or type(totals) ~= "table" then return 1 end
	local snaps = b.Snaps
	table.insert(snaps, { At = now, D = totals })
	local window = math.max(0, num(c.Window, 15))
	while #snaps > 1 and snaps[2].At <= now - window do table.remove(snaps, 1) end
	local base = snaps[1]
	local rate = b.BaseHP / math.max(1, num(c.SoloSeconds, 120))
	local rise = math.max(0.5, num(c.Rise, 2))
	local radius, sum = math.max(0, num(c.Radius, 50)), 0
	for p, d in totals do
		local b0 = num(base.D[p])
		local recent = num(d) - b0
		if recent > 0 and p.Parent ~= nil and S.PlayerService.IsReady(p) and Util.IsAlive(p) then
			local r = Util.GetRoot(p)
			if r and Util.FlatDistance(r.Position, pos) <= radius then
				local since = base.At -- the last snapshot before this player's first hit in the window
				for i = 2, #snaps - 1 do
					if num(snaps[i].D[p]) <= b0 then since = snaps[i].At end
				end
				local pace = rate * math.max(rise, now - since)
				sum += (c.ByDamage == false or pace <= 0) and 1 or math.min(1, recent / pace)
			end
		end
	end
	return math.clamp(math.floor(sum * 10 + 0.5) / 10, 1, math.max(1, num(c.Max, 10)))
end

-- MaxHP for `hunters` (whole HP): base x (1 + PerHunter x (hunters - 1))
function CROWD.MaxHP(base, c, hunters)
	return math.max(1, math.floor(base * (1 + math.max(0, num(c.PerHunter, 0.5)) * (math.max(1, hunters) - 1)) + 0.5))
end

-- every c.Every s while the boss is here: recount and set its MaxHP (the HP fraction stays)
function CROWD.Tick(key, now)
	local b = B[key]
	local c = CROWD.Of(key)
	if not c or b.Rec == nil or num(b.BaseHP) <= 0 or now < num(b.CrowdAt) then return end
	b.CrowdAt = now + math.max(0.5, num(c.Every, 2))
	b.Hunters = CROWD.Count(b, c, now)
	local want = CROWD.MaxHP(b.BaseHP, c, b.Hunters)
	if want ~= b.Rec.MaxHP and type(S.MonsterService.SetEventMaxHP) == "function" then
		local ok, err = pcall(S.MonsterService.SetEventMaxHP, b.Rec, want)
		if not ok then warnThrottled("crowd_" .. key, err) end
	end
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
	local ok, got = pcall(S.LootService.GrantItem, player, W.Item, n, "Reward") -- a reward fits a full bag (10/14)
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
	local ok, rec = pcall(svc.SpawnEvent, kindOf(key), { Near = near, Radius = math.max(0, num(c.Radius, 2)),
		MaxY = c.MaxY }) -- MaxY: a hill-top spot (the King Slime's shrine) may stand higher than normal ground
	if not ok or type(rec) ~= "table" then
		if not ok then warnThrottled("spawn_" .. key, rec) end
		return false
	end
	b.Rec, b.EndsAt = rec, now + math.max(1, num(c.Lifetime, 300))
	-- A23-113 ⑦: the def HP = one hunter; the first count comes one Every later against an empty snapshot
	local crowd = CROWD.Of(key)
	b.BaseHP, b.Hunters, b.Snaps = math.max(0, num(rec.MaxHP)), 1, { { At = now, D = {} } }
	b.CrowdAt = now + math.max(0.5, num(crowd and crowd.Every, 2))
	publish(key)
	announce(key .. "Appear")
	return true
end

-- the boss is gone: defeated (MonsterService already paid) or leaving (removed without rewards)
local function finish(key, defeated)
	local b = B[key]
	local rec = b.Rec
	b.Rec, b.EndsAt = nil, 0
	b.Snaps = {} -- A23-113 ⑦: no Player references kept until the next one
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
		else
			if b.NextAt > 0 and now >= b.NextAt then
				b.NextAt += math.max(60, num(c.Interval, 480)) -- a slot while one is still here (a Studio spawn) is skipped
				publish(key)
			end
			CROWD.Tick(key, now)
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
-- seconds until field boss `key` can be met: 0 = here now (or due, waiting for a hunter), nil = off / unknown
function FieldBossService.SecondsUntil(key)
	local b = B[key]
	if not b or cfg(key).Enabled == false then return nil end
	if b.Rec ~= nil and b.Rec.Alive == true then return 0 end
	if num(b.NextAt) <= 0 then return nil end
	return math.max(0, num(b.NextAt) - Util.Now())
end

function FieldBossService.IsActive(key)
	local b = B[key]
	return b ~= nil and b.Rec ~= nil and b.Rec.Alive == true
end

-- A23-113 ⑦: the hunters counted at the boss last time (0 = not here)
function FieldBossService.Hunters(key)
	local b = B[key]
	return (b ~= nil and b.Rec ~= nil) and num(b.Hunters, 1) or 0
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
			B[key] = { Rec = nil, EndsAt = 0, Defeats = 0, BaseHP = 0, Hunters = 0, CrowdAt = 0, Snaps = {},
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
