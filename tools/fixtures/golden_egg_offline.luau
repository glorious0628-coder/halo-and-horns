-- A23-131 / A23-134 / A23-137 golden egg hunt (GooseEggs + GooseService in Mode "Eggs"; the tug in Mode "Tug"), run offline.
-- tools/test_golden_egg.py injects the CURRENT sources before this file (CONFIG_SOURCE, EGGS_SOURCE, GOOSE_SOURCE).
-- Only engine / service boundaries are doubles (GooseEggs.World, the registry); every check is named and collected.

------------------------------------------------------------------ check collection
local results, order, findings = {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
local groupWarnings = {}

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

local function runGroup(name, fn)
	currentGroup = name
	groupWarnings = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	check(#groupWarnings == 0, "no unexpected warnings", groupWarnings[1])
end

local function show(v)
	if type(v) ~= "table" then return tostring(v) end
	if v.__kind == "Vector3" then return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
	local parts = {}
	for k, x in v do table.insert(parts, tostring(k) .. "=" .. show(x)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
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
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

local CONFIG = execute("Config", CONFIG_SOURCE, nativeEnv())
local E = CONFIG.Goose.Egg
local TICK = 0.125 -- the fixture's step (exact in binary, so 60 s is exactly 480 steps); the server uses Egg.Tick

local function seeded(seed)
	local state = seed
	return function()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

------------------------------------------------------------------ the world (GooseEggs + optionally GooseService)
-- opts: Mode ("Eggs" | "Tug"), Edit(config), Seed, Service (load GooseService too)
local function newWorld(opts)
	opts = opts or {}
	local w = { Now = 1790000000, Clock = 100, Players = {}, Fx = {}, Notices = {}, All = {}, Bag = {}, Refresh = {},
		Warn = {}, Parts = {}, Water = {}, High = {}, Props = {}, Implausible = {}, PlausibleCalls = 0, War = {},
		Gold = {}, XP = {}, Stats = {}, Fame = {}, Finished = {}, Paid = {}, AllowWarn = {} }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	config.Goose.Mode = opts.Mode or "Eggs"
	-- 최종 검수 10/14 ③: opts.Square = a GooseSquare stand-in (the marks on the ring's spots; w.Square.In[p] = in the square)
	if opts.Square then
		local sq = { In = {} }
		local function v(x, z) return setmetatable({ X = x, Y = 0, Z = z }, getmetatable(vec(0, 0, 0))) end
		function sq.Init() end
		function sq.Ensure()
			return { GooseSpot = v(0, 0), Nest = v(-30, -30), Cart = v(-30, 30), SpawnHalo = v(60, -40), SpawnHorns = v(60, 40),
				SpawnNeutral = v(70, 0) }
		end
		function sq.Members()
			local list = {}
			for p in sq.In do table.insert(list, p) end
			return list
		end
		function sq.IsIn(p) return sq.In[p] == true end
		function sq.Leave(p) sq.In[p] = nil end
		function sq.Forget() end
		function sq.OnRemote() end
		function sq.ReturnAll() sq.In = {} end
		function sq.TakeJoins() return 0 end
		function sq.Tick() end
		function sq.CountIn(f)
			local n = 0
			for p in sq.In do if p.Faction == f then n += 1 end end
			return n
		end
		w.Square = sq
	end
	if not opts.Live then -- a quiet goose (no laying, naps, chases or crown): the rule under test alone
		local Q = config.Goose.Egg
		Q.Rate = { Base = 0, PerPlayer = 0, Min = 0, Max = 0, Recount = 5 }
		Q.Naps, Q.Chases, Q.Sneeze, Q.ArrivalFeathers = {}, {}, 0, 0
		Q.Crown.At, Q.Crown.Gold = 1e9, 0
	end
	if opts.Edit then opts.Edit(config) end
	w.Config = config
	local gs = { Parent = {}, Attrs = {} }
	function gs:SetAttribute(k, v) self.Attrs[k] = v end
	function gs:GetAttribute(k) return self.Attrs[k] end
	w.GS = gs
	local net = { GameState = function() return gs end }
	function net.Notify(p, text, kind) table.insert(w.Notices, { Player = p, Text = text, Kind = kind }) end
	function net.NotifyAll(text, kind, duration) table.insert(w.All, { Text = text, Kind = kind, Duration = duration }) end
	function net.Fx(p, kind, data) table.insert(w.Fx, { Player = p, Kind = kind, Data = data }) end
	function net.Get() return { OnServerEvent = { Connect = function() end } } end -- (the square's remote; opts.Square)
	local util = { Signal = { new = signal }, Now = function() return w.Now end, FormatNumber = tostring,
		PlayerDisplayName = function(p) return p.Name end, Random = { NextNumber = function() return 0.999 end },
		Warn = function(tag, msg)
			msg = tostring(msg)
			for _, part in w.AllowWarn do if string.find(msg, part, 1, true) then return end end
			if not string.find(msg, "goose model failed", 1, true) then table.insert(groupWarnings, tag .. ": " .. msg) end
		end,
		GetFolder = function() return { FindFirstChild = function() return nil end } end }
	local playersSvc = { GetPlayers = function() return {} end }
	local services = { ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		ServerStorage = { FindFirstChild = function() return nil end }, RunService = { Heartbeat = signal() }, Players = playersSvc }
	local eggs
	local function env()
		local e = nativeEnv()
		local cfmt = {}
		local function cf() return setmetatable({ __kind = "CFrame" }, cfmt) end
		cfmt.__mul = function() return cf() end
		cfmt.__add = function() return cf() end
		cfmt.__sub = function() return cf() end
		e.CFrame = { new = cf, Angles = cf, lookAt = cf }
		e.game = { GetService = function(_, name) return assert(services[name], name) end }
		e.workspace = { FindFirstChild = function() return nil end }
		e.typeof, e.print, e.warn = typeofDouble, function() end, function() end
		e.os = setmetatable({ clock = function() return w.Clock end, time = function() return math.floor(w.Now) end }, { __index = os })
		e.task = { spawn = function(fn) w.Loop = coroutine.create(fn) end, wait = function(d) return coroutine.yield(d) end,
			delay = function() end, defer = function(fn, ...) fn(...) end }
		e.script = { Parent = { FindFirstChild = function(_, n)
			if n == "GooseSquare" and w.Square then return "GooseSquare" end
			return n == "GooseEggs" and "GooseEggs" or nil
		end } }
		e.require = function(name)
			if name == "Config" then return config elseif name == "Util" then return util elseif name == "Net" then return net
			elseif name == "GooseEggs" then return eggs elseif name == "GooseSquare" and w.Square then return w.Square end
			error("unexpected require " .. tostring(name))
		end
		return e
	end
	eggs = execute("GooseEggs", EGGS_SOURCE, env())
	w.Eggs = eggs
	local rnd = seeded(opts.Seed or 4242)
	local W = eggs.World
	W.Warn = function(msg) util.Warn("GooseEggs", msg) end
	W.Random = function() return rnd() end
	W.Players = function()
		local out = {}
		for _, p in w.Players do if p.Parent ~= nil and p.Ready then table.insert(out, p) end end
		return out
	end
	W.Faction = function(p) return p.Faction end
	W.RootPos = function(p) return p.Pos end
	W.Blocked = function(p) return p.Blocked == true end
	W.Plausible = function(p) w.PlausibleCalls += 1; return not w.Implausible[p] end
	W.Ground = function(pos)
		for _, r in w.Water do if flat(pos, r.At) <= r.R then return 0, true end end
		for _, r in w.High do if flat(pos, r.At) <= r.R then return r.Y, false end end
		return 0, false
	end
	W.PropHit = function(pos)
		for _, r in w.Props do if flat(pos, r.At) <= r.R then return true end end
		return false
	end
	W.MakeEgg = function(egg) w.Parts[egg.Id] = { Kind = egg.Kind, Pos = egg.Pos, From = egg.From, LandAt = egg.LandAt, Points = egg.Points }; egg.View = true end
	W.MoveEgg = function(egg) local v = w.Parts[egg.Id]; if v then v.Pos, v.From, v.LandAt = egg.Pos, egg.From, egg.LandAt end end
	W.RemoveEgg = function(egg) w.Parts[egg.Id] = nil end
	W.ClearEggs = function() w.Parts = {} end
	W.Fx = function(kind, data) table.insert(w.Fx, { Kind = kind, Data = data, T = w.Now }) end
	W.Refresh = function(p) w.Refresh[p] = (w.Refresh[p] or 0) + 1 end
	W.Grant = function(p, id, n) w.Bag[p] = w.Bag[p] or {}; w.Bag[p][id] = (w.Bag[p][id] or 0) + n end

	local serial = 0
	function w:Add(name, faction, pos, level)
		serial += 1
		local p = { __kind = "Instance", Name = name, UserId = 1000 + serial, Parent = playersSvc, Attrs = {}, Faction = faction,
			Pos = pos, Ready = true, Data = { Level = level or 1, CheerStars = 0, Honor = 0, Infamy = 0, EggHonorAt = 0 } }
		function p:SetAttribute(k, v) self.Attrs[k] = v end
		function p:GetAttribute(k) return self.Attrs[k] end
		function p:IsA(k) return k == "Player" or k == "Instance" end
		table.insert(self.Players, p)
		self[name] = p
		return p
	end
	function w:Begin(mode, side)
		eggs.Begin(self.Now, mode or "Versus", side)
		self.Parts = {}
		for id in eggs.Round().Eggs do eggs.Round().Eggs[id] = nil end -- tests place their own eggs
		self.Fx = {}
	end
	function w:Step(n, mover)
		local last
		for _ = 1, n or 1 do
			self.Now += TICK
			self.Clock += TICK
			if mover then mover(self) end
			last = eggs.Step(self.Now, {})
		end
		return last
	end
	function w:Egg(kind, pos, points) return eggs.DebugEgg(self.Now, kind, pos, points) end
	-- p walks back and forth by 2 studs per tick around `at` (the away rule needs 1 stud in 0.5 s)
	-- p circles `center` at radius r (a constant distance; 4 ticks = 0.5 s move 1.73 r studs: the away rule passes)
	function w:Orbit(p, center, r, y)
		local k = math.floor((self.Now - 1790000000) / TICK + 0.5)
		local a = k * math.pi / 3
		p.Pos = vec(center.X + math.cos(a) * r, y or p.Pos.Y, center.Z + math.sin(a) * r)
	end
	function w:Jiggle(p, at) self:Orbit(p, at, 0.7, at.Y) end
	-- p walks to `to` at `speed` studs/s (one step per tick); returns the ticks used
	function w:WalkTo(p, to, speed, limit)
		local n = 0
		while flat(p.Pos, to) > 0.05 and n < (limit or 600) do
			n += 1
			self:Step(1, function()
				local d = flat(p.Pos, to)
				local s = math.min(d, (speed or 16) * TICK)
				p.Pos = vec(p.Pos.X + (to.X - p.Pos.X) / d * s, to.Y, p.Pos.Z + (to.Z - p.Pos.Z) / d * s)
			end)
		end
		return n
	end
	-- steps until the round's elapsed time reaches t (others jiggle in place when listed)
	-- returns the first non-nil Step result on the way (e.g. "Done") and the elapsed time it came at
	function w:Until(t, movers)
		local first, at = nil, nil
		while self.Now - eggs.Round().T0 < t - 1e-6 do
			local r = self:Step(1, function()
				for p, pos in movers or {} do self:Jiggle(p, pos) end
			end)
			if r ~= nil and first == nil then first, at = r, self.Now - eggs.Round().T0 end
		end
		return first, at
	end
	function w:FxOf(kind)
		local out = {}
		for _, f in self.Fx do if f.Kind == kind then table.insert(out, f.Data) end end
		return out
	end
	function w:Ground()
		local n = 0
		for _ in eggs.Round().Eggs do n += 1 end
		return n
	end
	function w:St(p) return eggs.Round().Players[p] end

	if opts.Service then
		local ps = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterDied = signal(),
			IsReady = function(p) return p.Ready == true and p.Parent ~= nil end, GetData = function(p) return p.Data end,
			GetReadyPlayers = W.Players, GetLuckEvents = function() return 0 end, RefreshSpeed = function() end }
		function ps.AddStat(p, key, n) p.Data[key] = (p.Data[key] or 0) + n; table.insert(w.Stats, { P = p, Key = key, N = n }); return p.Data[key] end
		-- A23-134 '(주간 상한 안)': the stat + the weekly board (RankPoints = the board credit, capped by RankingService)
		function ps.GrantFame(p, key, n, ctx)
			table.insert(w.Fame, { P = p, Key = key, N = n, Ctx = ctx })
			return ps.AddStat(p, key, n)
		end
		function ps.SetStat(p, key, v) p.Data[key] = v end
		w.Registry = { PlayerService = ps,
			FactionService = { FactionChanged = signal(), GetFaction = function(p) return p.Faction end,
				GetCounts = function()
					local h, r = 0, 0
					for _, p in W.Players() do
						if p.Faction == "Halo" then h += 1 elseif p.Faction == "Horns" then r += 1 end
					end
					return h, r
				end },
			ProgressionService = { AddBankGold = function(p, g) w.Gold[p] = (w.Gold[p] or 0) + g; return g end,
				AddXP = function(p, x) w.XP[p] = (w.XP[p] or 0) + x; return x end },
			WarService = { GetRoundEndsAt = function() return nil end, AddFactionPoints = function(fac, n) table.insert(w.War, { fac, n }) end },
			JusticeService = { GetFactionScale = function() return 1 end } }
		local goose = execute("GooseService", GOOSE_SOURCE, env())
		goose.GooseFinished:Connect(function(result, rewarded, info) table.insert(w.Finished, { Result = result, Rewarded = rewarded, Info = info }) end)
		goose.GooseRewarded:Connect(function(p, info) table.insert(w.Paid, { P = p, Info = info }) end)
		w.Goose = goose
		goose.Init(w.Registry)
		-- GooseEggs.Init happens in GooseService.Init; the doubles above stay (World is a shared table)
		goose.Start()
		assert(coroutine.resume(w.Loop))
		function w:Tick(n)
			for _ = 1, n or 1 do
				local ok, err = coroutine.resume(self.Loop)
				assert(ok, err)
			end
		end
	end
	return w
end

------------------------------------------------------------------ groups
local SPOT = vec(24, 0, 0) -- a valid egg spot (outside the basin, far from homes / altar / spawn / pads)

runGroup("config", function()
	local K = E.Kinds
	check(CONFIG.Goose.Mode == "Eggs", "Config.Goose.Mode = Eggs", CONFIG.Goose.Mode)
	check(K.Gold.Points == 10 and K.Gold.Slots == 1 and K.Bouncy.Points == 20 and K.Bouncy.Slots == 1 and K.Big.Points == 30
		and K.Big.Slots == 3 and K.Crown.Points == 50 and K.Crown.Slots == 3 and K.Feather.Points == 0 and K.Feather.Slots == 0,
		"contract §2 kinds (points / slots)", show(K))
	check(E.MaxSlots == 3 and E.PickRadius == 4.5 and E.PickHeight == 6 and E.RingRadius == 54 and E.WobbleFrom == 45
		and E.HomeRadius == 8 and E.IdleReturn == 10 and E.IdleWobble == 7 and E.FlyTime == 0.7, "contract §2 numbers")
	check(E.Home.Halo.X == -30 and E.Home.Halo.Z == -30 and E.Home.Horns.X == -30 and E.Home.Horns.Z == 30 and E.Center.X == 0,
		"homes: Halo nest (-30,0,-30), Horns cart (-30,0,30)")
	local T = E.Tag
	check(T.On == true and T.Radius == 3 and T.Hold == 1 and T.Shield == 3 and T.Cooldown == 4, "egg tag ON 3 / 1 / 3 / 4 (A23-134)", show(T))
	check(CONFIG.Goose.WinWarPoints == 30, "winning side +30 crown-war points (A23-137)", CONFIG.Goose.WinWarPoints)
	check(CONFIG.Goose.Schedule.Every == 14400 and CONFIG.Goose.Schedule.TzOffset == 32400, "every 4 h on the KST clock")
	check(E.CoopPerPerson == 80 and E.MinDelivered == 2 and E.MinPoints == 20 and E.MinCrowd == 1 and E.CrowdFrom == 16,
		"co-op 80 per ring entrant; 2 eggs or 20 points (1 egg from P 16)")
	check(CONFIG.GooseEggSpeed(0) == 20 and CONFIG.GooseEggSpeed(1) == 18 and CONFIG.GooseEggSpeed(2) == 16
		and CONFIG.GooseEggSpeed(3) == 14 and CONFIG.GooseEggSpeed(1, true) == 14, "plaza speed 20 / 18 / 16 / 14, heavy x0.7",
		show({ CONFIG.GooseEggSpeed(0), CONFIG.GooseEggSpeed(1), CONFIG.GooseEggSpeed(2), CONFIG.GooseEggSpeed(3), CONFIG.GooseEggSpeed(1, true) }))
	local L = CONFIG.Loot
	local o = L.Order
	local petal = table.find(o, "Petal")
	check(L.Items.GoldenEgg and L.Items.GoldenEgg.Kind == "Material" and L.Items.GoldenEgg.Name == "Golden Egg" and L.Items.GoldenEgg.Sell == 25
		and L.Items.GoldenEgg.Source == "Goose" and L.Items.GooseFeather and L.Items.GooseFeather.Name == "Goose Feather"
		and L.Items.GooseFeather.Sell == 10 and L.Items.GooseFeather.Source == "Goose", "GoldenEgg 25 / GooseFeather 10 materials (Source Goose)")
	check(petal and o[petal + 1] == "GoldenEgg" and o[petal + 2] == "GooseFeather", "both listed right after Petal")
	check(CONFIG.Goose.Text.BringTwo == "Bring 2 eggs for a reward.", "the one fail line")
end)

runGroup("pick-rules", function()
	-- distance (4.5 + 0.5 slack), moving
	local w = newWorld()
	local h = w:Add("H1", "Halo", vec(SPOT.X + 4.9, 3, 0))
	w:Begin()
	w:Egg("Gold", SPOT)
	w:Step(8, function() w:Orbit(h, SPOT, 4.9) end)
	check(h.Attrs.EggCarry == 1 and w:Ground() == 0, "flat 4.9 (within 4.5 + 0.5): picked", show({ h.Attrs.EggCarry, w:Ground() }))
	local w2 = newWorld()
	local h2 = w2:Add("H1", "Halo", vec(SPOT.X + 5.1, 3, 0))
	w2:Begin()
	w2:Egg("Gold", SPOT)
	w2:Step(8, function() w2:Orbit(h2, SPOT, 5.1) end)
	check((h2.Attrs.EggCarry or 0) == 0 and w2:Ground() == 1, "flat 5.1: not picked", show({ h2.Attrs.EggCarry }))
	-- height 6 + 0.5
	local w3 = newWorld()
	local a = w3:Add("A", "Halo", vec(SPOT.X + 1, 6.4, 0))
	local b = w3:Add("B", "Halo", vec(SPOT.X + 1, 6.6, 20))
	w3:Begin()
	w3:Egg("Gold", SPOT)
	local spotB = vec(SPOT.X, 0, 20)
	w3:Egg("Gold", spotB)
	w3:Step(8, function() w3:Orbit(a, SPOT, 1, 6.4); w3:Orbit(b, spotB, 1, 6.6) end)
	check(a.Attrs.EggCarry == 1 and (b.Attrs.EggCarry or 0) == 0, "height 6.4 picked, 6.6 not", show({ a.Attrs.EggCarry, b.Attrs.EggCarry }))
	-- the away rule: standing still on an egg never picks
	local w4 = newWorld()
	local s = w4:Add("S", "Halo", vec(SPOT.X, 3, 0))
	w4:Begin()
	w4:Egg("Gold", SPOT)
	w4:Step(20)
	check((s.Attrs.EggCarry or 0) == 0 and w4:Ground() == 1, "not moving 1 stud in 0.5 s: no pick")
	-- a flying egg is not pickable before it lands
	local w5 = newWorld()
	local f = w5:Add("F", "Halo", vec(SPOT.X + 1, 3, 0))
	w5:Begin()
	w5.Eggs.DebugEgg(w5.Now, "Gold", SPOT, nil, w5.Now + 0.7)
	local pf = f.Pos
	w5:Step(5, function() w5:Jiggle(f, pf) end)
	check((f.Attrs.EggCarry or 0) == 0, "not picked while it flies (LandAt)")
	w5:Step(4, function() w5:Jiggle(f, pf) end)
	check(f.Attrs.EggCarry == 1, "picked once landed")
	-- ZoneService.IsPlausible on each pick
	local w6 = newWorld()
	local t = w6:Add("T", "Halo", vec(SPOT.X + 1, 3, 0))
	w6.Implausible[t] = true
	w6:Begin()
	w6:Egg("Gold", SPOT)
	local pt = t.Pos
	w6:Step(8, function() w6:Jiggle(t, pt) end)
	check((t.Attrs.EggCarry or 0) == 0 and w6.PlausibleCalls > 0, "an implausible position picks nothing", w6.PlausibleCalls)
end)

runGroup("slots", function()
	local w = newWorld()
	local full = w:Add("Full", "Halo", vec(24, 3, 0))
	local one = w:Add("One", "Halo", vec(0, 3, 24))
	local empty = w:Add("Empty", "Halo", vec(-24, 3, 0))
	local two = w:Add("Two", "Halo", vec(20, 3, 30))
	w:Begin()
	for _ = 1, 3 do w:Egg("Gold", vec(24, 0, 0)) end
	w:Egg("Gold", vec(0, 0, 24))
	w:Egg("Gold", vec(20, 0, 30)); w:Egg("Gold", vec(20, 0, 30))
	local pos = { [full] = full.Pos, [one] = one.Pos, [empty] = empty.Pos, [two] = two.Pos }
	local mover = function() for p, at in pos do w:Jiggle(p, at) end end
	w:Step(8, mover)
	check(full.Attrs.EggCarry == 3 and one.Attrs.EggCarry == 1 and two.Attrs.EggCarry == 2, "three eggs in one tick fill 3 slots",
		show({ full.Attrs.EggCarry, one.Attrs.EggCarry, two.Attrs.EggCarry }))
	w:Egg("Gold", vec(24, 0, 0)); w:Egg("Big", vec(0, 0, 24)); w:Egg("Big", vec(-24, 0, 0)); w:Egg("Gold", vec(20, 0, 30))
	w:Step(8, mover)
	check(full.Attrs.EggCarry == 3, "full hands skip a gold egg", full.Attrs.EggCarry)
	check(one.Attrs.EggCarry == 1, "a big egg (3 slots) needs empty hands", one.Attrs.EggCarry)
	check(empty.Attrs.EggCarry == 3, "empty hands pick a big egg (3 slots)", empty.Attrs.EggCarry)
	check(two.Attrs.EggCarry == 3, "2 + 1 = 3 fits", two.Attrs.EggCarry)
	check(w:Ground() == 2, "the skipped eggs stay on the ground", w:Ground())
end)

runGroup("pairing", function()
	-- nearest first
	local w = newWorld()
	local near = w:Add("Near", "Halo", vec(SPOT.X - 2, 3, 0))
	local far = w:Add("Far", "Halo", vec(SPOT.X + 3, 3, 0))
	w:Begin()
	local mv = function() w:Orbit(near, SPOT, 2); w:Orbit(far, SPOT, 3) end
	w:Step(5, mv)
	w:Egg("Gold", SPOT)
	w:Step(1, mv)
	check(near.Attrs.EggCarry == 1 and (far.Attrs.EggCarry or 0) == 0, "two in reach: the nearer picks", show({ near.Attrs.EggCarry, far.Attrs.EggCarry }))
	-- equal distance: fewer deliveries this round
	local t = newWorld()
	local busy = t:Add("Busy", "Halo", vec(SPOT.X - 2.5, 3, 0))
	local fresh = t:Add("Fresh", "Halo", vec(SPOT.X + 2.5, 3, 0))
	t:Begin()
	local mt = function() t:Orbit(busy, SPOT, 2.5); t:Orbit(fresh, SPOT, 2.5) end
	t:Step(5, mt)
	t:St(busy).Delivered = 1
	t:Egg("Gold", SPOT)
	t:Step(1, mt)
	check(fresh.Attrs.EggCarry == 1 and (busy.Attrs.EggCarry or 0) == 0, "a tie goes to the one with fewer deliveries",
		show({ fresh.Attrs.EggCarry, busy.Attrs.EggCarry }))
	-- EggCan: kaiju / sack, None, co-op rival false; Neutral true
	local c = newWorld()
	local k = c:Add("Kaiju", "Horns", vec(24, 3, 0)); k.Blocked = true
	local none = c:Add("None", "None", vec(0, 3, 24))
	local neu = c:Add("Neu", "Neutral", vec(-24, 3, 0))
	local rival = c:Add("Rival", "Horns", vec(20, 3, 30))
	local mate = c:Add("Mate", "Halo", vec(20, 3, -30))
	c:Begin("Coop", "Halo")
	c:Step(1)
	check(k.Attrs.EggCan == false and none.Attrs.EggCan == false and rival.Attrs.EggCan == false and neu.Attrs.EggCan == true
		and mate.Attrs.EggCan == true, "EggCan: kaiju / None / late rival false, Neutral and the co-op side true",
		show({ k.Attrs.EggCan, none.Attrs.EggCan, rival.Attrs.EggCan, neu.Attrs.EggCan, mate.Attrs.EggCan }))
	c:Egg("Gold", vec(24, 0, 0)); c:Egg("Gold", vec(20, 0, 30))
	local pk, pr2 = k.Pos, rival.Pos
	c:Step(8, function() c:Jiggle(k, pk); c:Jiggle(rival, pr2) end)
	check((k.Attrs.EggCarry or 0) == 0 and (rival.Attrs.EggCarry or 0) == 0 and c:Ground() == 2, "they never pick")
end)
runGroup("plaza-speed", function()
	local w = newWorld()
	local h = w:Add("H1", "Halo", vec(SPOT.X + 1, 3, 0))
	local out = w:Add("Out", "Halo", vec(60, 3, 0))
	w:Begin()
	local at = h.Pos
	w:Step(2, function() w:Jiggle(h, at) end)
	check(h.Attrs.EggPlaza == true and out.Attrs.EggPlaza ~= true, "EggPlaza: inside the ring yes, outside no",
		show({ h.Attrs.EggPlaza, out.Attrs.EggPlaza }))
	local before = w.Refresh[h] or 0
	w:Egg("Gold", SPOT)
	w:Step(6, function() w:Jiggle(h, at) end)
	check(h.Attrs.EggCarry == 1 and (w.Refresh[h] or 0) > before, "a pick sets EggCarry and refreshes the speed",
		show({ h.Attrs.EggCarry, w.Refresh[h], before }))
	local r = w.Refresh[h]
	h.Pos = vec(56, 3, 0)
	w:Step(1)
	check(h.Attrs.EggPlaza == false and (h.Attrs.EggCarry or 0) == 0 and w.Refresh[h] > r, "leaving the ring: plaza off, eggs back, speed refreshed")
end)

runGroup("deliver", function()
	local w = newWorld()
	local h = w:Add("H1", "Halo", vec(-30, 3, -10))
	w:Begin()
	local at = h.Pos
	w:Egg("Gold", vec(-30, 0, -10)); w:Egg("Gold", vec(-30, 0, -10))
	w:Step(6, function() w:Jiggle(h, at) end)
	check(h.Attrs.EggCarry == 2, "carrying 2", h.Attrs.EggCarry)
	w:WalkTo(h, vec(-30, 3, -30), 16)
	local R = w.Eggs.Round()
	check(h.Attrs.GooseCount == 20 and h.Attrs.EggDelivered == 2 and R.Rescue == 20 and R.Poach == 0 and (h.Attrs.EggCarry or 0) == 0,
		"own home ring: 2 eggs = 20 points, EggDelivered 2, totals", show({ h.Attrs.GooseCount, h.Attrs.EggDelivered, R.Rescue }))
	local fx = w:FxOf("EggDeliver")[1]
	check(fx and fx.UserId == h.UserId and fx.N == 2 and fx.Points == 20 and fx.Side == "Halo" and fx.Pos.Z == -30, "Fx EggDeliver { UserId, Pos, N, Points, Side }", show(fx))
	-- the other side's home does nothing
	w:Egg("Gold", vec(-30, 0, 10))
	w:WalkTo(h, vec(-30, 3, 10), 16)
	w:WalkTo(h, vec(-30, 3, 30), 12)
	check(h.Attrs.EggCarry == 1 and R.Rescue == 20 and R.Poach == 0, "the rival's cart scores nothing", show({ h.Attrs.EggCarry, R.Poach }))
	-- the cheat check: a pick at 24 studs from the nest delivered 0.125 s later is logged, and only logged (Enforce false)
	local q = newWorld()
	q.AllowWarn = { "egg delivery too fast" }
	local t = q:Add("T", "Halo", vec(24, 3, -10))
	q:Begin()
	q:Egg("Gold", vec(24, 0, -10))
	local pt = t.Pos
	q:Step(6, function() q:Jiggle(t, pt) end)
	t.Pos = vec(-30, 3, -30)
	q:Step(1)
	check(q.Eggs.Round().CheatLogs == 1 and q.Eggs.Round().Rescue == 10, "too fast: logged, still scored (log only)",
		show({ q.Eggs.Round().CheatLogs, q.Eggs.Round().Rescue }))
	check(w.Eggs.Round().CheatLogs == 0, "a normal walk is never logged")
end)

runGroup("h-factor", function()
	-- 1 Halo vs 4 Horns in the ring all round: Halo x2 (sqrt 4), Horns x1
	local function world(horns)
		local w = newWorld()
		local h = w:Add("H1", "Halo", vec(-30, 3, -10))
		local hs = {}
		for i = 1, horns do table.insert(hs, w:Add("R" .. i, "Horns", vec(30, 3, -20 + i * 6))) end
		w:Begin()
		return w, h, hs
	end
	local w, h, hs = world(4)
	local at = h.Pos
	w:Step(5, function() w:Jiggle(h, at) end)
	w:Egg("Gold", vec(-30, 0, -10))
	w:Step(2, function() w:Jiggle(h, at) end)
	w:WalkTo(h, vec(-30, 3, -30), 16)
	check(w.Eggs.Round().Rescue == 20 and h.Attrs.GooseCount == 20, "1:4 -> the fewer side's egg x2", show({ w.Eggs.Round().Rescue }))
	check(w.Eggs.HFor("Horns", w.Now) == 1, "the bigger side gets x1")
	-- 2:3 -> x1.22, rounded to an integer
	local v, a = world(3)
	local b = v:Add("H2", "Halo", vec(-20, 3, -10))
	v:Step(1)
	v.Eggs.Round().Presence.Halo = 0; v.Eggs.Round().Presence.Horns = 0 -- H2 counted from now on, like the others
	local pa, pb = a.Pos, b.Pos
	v:Step(10, function() v:Jiggle(a, pa); v:Jiggle(b, pb) end)
	v:Egg("Gold", vec(-30, 0, -10))
	v:Step(2, function() v:Jiggle(a, pa); v:Jiggle(b, pb) end)
	v:WalkTo(a, vec(-30, 3, -30), 16)
	local got = v.Eggs.Round().Rescue
	check(got == 12 and math.floor(got) == got, "2:3 -> 10 x 1.22 = 12 (one integer)", got)
	-- 1:9 -> sqrt 9 = 3, capped at 2
	local c9, h9 = world(9)
	local a9 = h9.Pos
	c9:Step(5, function() c9:Jiggle(h9, a9) end)
	c9:Egg("Gold", vec(-30, 0, -10))
	c9:Step(2, function() c9:Jiggle(h9, a9) end)
	c9:WalkTo(h9, vec(-30, 3, -30), 16)
	check(c9.Eggs.Round().Rescue == 20, "1:9 -> x2 (the cap), not x3", c9.Eggs.Round().Rescue)
	-- N = average presence: three Horns who left early count less
	local x, hx, rx = world(3)
	x:Step(10)
	for _, p in rx do p.Pos = vec(80, 3, 0) end
	x:Step(30)
	local hval = x.Eggs.HFor("Halo", x.Now)
	check(hval < 1.5 and hval >= 1, "N = average ring presence (3 who left early weigh less)", hval)
	local _ = hx
end)
-- a world with one Halo carrier holding one gold egg (picked at `at`)
local function carrier(at)
	local w = newWorld()
	local h = w:Add("H1", "Halo", at or vec(SPOT.X + 1, 3, 0))
	w:Begin()
	local p0 = h.Pos
	w:Egg("Gold", vec(p0.X - 1, 0, p0.Z))
	w:Step(6, function() w:Jiggle(h, p0) end)
	assert(h.Attrs.EggCarry == 1, "carrier setup")
	w.Fx = {}
	return w, h, p0
end

local function returned(w, h, reason)
	local fx = w:FxOf("EggReturn")
	return (h.Attrs.EggCarry or 0) == 0 and #fx >= 1 and #fx[1].Froms >= 1 and (w.Eggs.Round().Returns[reason] or 0) >= 1
end

runGroup("returns", function()
	-- ring edge 54
	local w, h = carrier()
	h.Pos = vec(53.5, 3, 0)
	w:Step(1)
	check(h.Attrs.EggCarry == 1, "at 53.5 still carried (ring 54)")
	h.Pos = vec(54.6, 3, 0)
	w:Step(1)
	check(returned(w, h, "Ring"), "past 54: the eggs return (Fx EggReturn)", show(w.Eggs.Round().Returns))
	-- standing still 10 s
	local i, hi, p = carrier()
	i:Step(math.floor(9.6 / TICK))
	check(hi.Attrs.EggCarry == 1, "still for 9.6 s: carried")
	i:Step(math.ceil(0.6 / TICK))
	check(returned(i, hi, "Idle"), "still for 10 s: back to the goose", show(i.Eggs.Round().Returns))
	local _ = p
	-- death, leave, faction change, pads / Travel
	local d, hd = carrier()
	hd.Pos = nil
	d:Step(1)
	check(returned(d, hd, "Death"), "dying returns the eggs", show(d.Eggs.Round().Returns))
	local l, hl = carrier()
	l.Eggs.Leave(hl)
	check(returned(l, hl, "Leave"), "leaving returns the eggs")
	local l2, hl2 = carrier()
	hl2.Parent = nil
	l2:Step(1)
	check((l2.Eggs.Round().Returns.Leave or 0) == 1 and #l2:FxOf("EggReturn") == 1, "a player gone from the list: eggs back")
	local f, hf = carrier()
	hf.Faction = "Horns"
	f:Step(1)
	check(returned(f, hf, "Faction"), "a faction change returns the eggs")
	local f2, hf2 = carrier()
	f2.Eggs.DropEntry(hf2)
	check(returned(f2, hf2, "Faction") and hf2.Attrs.GooseCount == 0, "DropEntry: eggs back, a fresh entry")
	local t, ht = carrier()
	t.Eggs.ReturnEggs(ht, "Travel")
	check(returned(t, ht, "Travel"), "pads / Travel return the eggs (GooseService.ReturnEggs)")
	local k, hk = carrier()
	hk.Blocked = true
	k:Step(1)
	check(returned(k, hk, "Blocked"), "turning kaiju / taking a sack returns the eggs")
	-- a ground egg nobody picks for 15 s
	local g = newWorld()
	g:Begin()
	g:Egg("Gold", SPOT)
	g:Step(math.floor(14.8 / TICK))
	check(g:Ground() >= 1 and g.Parts[1] ~= nil, "unpicked 14.8 s: still there")
	g:Step(math.ceil(0.4 / TICK))
	check(g.Parts[1] == nil and #g:FxOf("EggReturn") >= 1, "unpicked 15 s: back to the goose")
end)

runGroup("order-and-end", function()
	-- a delivery in the tick that crosses 60 s still counts (deliver -> return -> pick -> end)
	local w = newWorld()
	local h = w:Add("H1", "Halo", vec(-30, 3, -10))
	w:Begin()
	local at = h.Pos
	w:Egg("Gold", vec(-30, 0, -10))
	w:Until(50, { [h] = at })
	check(h.Attrs.EggCarry == 1, "carrying at 50 s")
	w:Until(59.8, { [h] = at })
	h.Pos = vec(-30, 3, -29)
	local res = w:Step(1)
	check(res == "Done" and w.Eggs.Round().Rescue == 10, "the last tick: delivered first, then the end", show({ res, w.Eggs.Round().Rescue }))
	-- the 60 s tick: ground eggs return, nothing is picked
	local g = newWorld()
	local p = g:Add("P", "Halo", vec(SPOT.X + 1, 3, 0))
	g:Begin()
	g:Until(59.8, { [p] = p.Pos })
	g:Egg("Gold", SPOT)
	local pp = p.Pos
	local r2 = g:Step(1, function() g:Jiggle(p, pp) end)
	check(r2 == "Done" and (p.Attrs.EggCarry or 0) == 0 and g:Ground() == 0, "at 60 s the ground eggs go back, none picked",
		show({ r2, p.Attrs.EggCarry, g:Ground() }))
	-- Finish: carried eggs return, attributes reset, folder empty
	local sum = w.Eggs.Finish(w.Now)
	check(sum and sum.Points[h] == 10 and sum.Delivered[h] == 1 and sum.Side[h] == "Halo" and sum.Rescue == 10, "Finish: the summary", show(sum and sum.Points))
	check(h.Attrs.EggCan == false and h.Attrs.EggPlaza == false and h.Attrs.EggCarry == 0 and not w.Eggs.IsActive(), "Finish resets EggCan / EggPlaza / EggCarry")
end)

runGroup("overtime", function()
	local function crownRun(deliverAt)
		local w = newWorld()
		local h = w:Add("H1", "Halo", vec(-20, 3, -12))
		w:Begin()
		local at = h.Pos
		w:Until(54, { [h] = at })
		w:Egg("Crown", vec(-20, 0, -12), 50)
		w:Step(3, function() w:Jiggle(h, at) end)
		return w, h, at
	end
	local w, h, at = crownRun()
	check(h.Attrs.EggCarry == 3, "carrying the crown egg (3 slots)", h.Attrs.EggCarry)
	w:Until(59.95, { [h] = at })
	local res = w:Step(1, function() w:Jiggle(h, at) end)
	local R = w.Eggs.Round()
	check(res == nil and math.abs(R.Overtime - (R.EndsAt + 8)) < 1e-6 and w.Eggs.OvertimeUntil() == R.Overtime,
		"a carried crown egg at 60 s: overtime until end + 8", show({ res, R.Overtime, R.EndsAt }))
	w:WalkTo(h, vec(-30, 3, -30), 14)
	check(R.Rescue == 50, "the crown delivered in overtime counts", R.Rescue)
	check(w:Step(1) == "Done", "no crown carried any more: the round ends")
	-- held until the overtime runs out
	local o, ho, ato = crownRun()
	local early, eat = o:Until(67.8, { [ho] = ato }) -- stops at 67.875 s
	check(early == nil and ho.Attrs.EggCarry == 3, "67.875 s: still overtime", show({ early, ho.Attrs.EggCarry, eat }))
	local done, when = o:Until(68.3, { [ho] = ato })
	check(done == "Done" and when >= 68 - 1e-6, "68 s: the overtime ends", show({ done, when }))
	-- no crown: ends at 60
	local n = newWorld()
	n:Begin()
	n:Until(59.95)
	check(n:Step(1) == "Done" and n.Eggs.OvertimeUntil() == 0, "no crown: done at 60 s, no overtime")
end)
runGroup("laying", function()
	-- no players: 0.6 eggs/s; arrival = 6 eggs + 3 feathers; laying stops at 55 s
	local w = newWorld({ Live = true })
	w.Eggs.Begin(w.Now, "Versus")
	local R = w.Eggs.Round()
	local feathers, golds = 0, 0
	for _, egg in R.Eggs do
		if egg.Kind == "Feather" then feathers += 1 elseif egg.Kind == "Gold" then golds += 1 end
	end
	check(golds == 6 and feathers == 3, "the arrival sneeze: 6 eggs and 3 feathers", show({ golds, feathers }))
	w:Until(1)
	local id1 = R.NextId
	w:Until(11)
	local laid = R.NextId - id1
	check(laid >= 5 and laid <= 7, "P 0: about 0.6 eggs per second", laid)
	-- a nap at 15 s: Act Nap until 17 s, a feather, then a big egg on the losing half (Halo behind)
	R.Poach = 50
	w:Until(15.25)
	check(R.Goose.Act == "Nap" and math.abs(R.Goose.ActUntil - (R.T0 + 17)) < 1e-6, "15 s: the goose naps 2 s", show({ R.Goose.Act, R.Goose.ActUntil - R.T0 }))
	local nf = 0
	for _, egg in R.Eggs do if egg.Kind == "Feather" then nf += 1 end end
	check(nf >= 1, "a feather when it naps", nf)
	local napId = R.NextId
	w:Until(16.75)
	check(R.NextId == napId, "no laying while it naps", R.NextId - napId)
	w:Until(17.25)
	local big
	for _, egg in R.Eggs do if egg.Kind == "Big" then big = egg end end
	check(big ~= nil and big.Pos.Z < 0 and big.Points == 30, "17 s: a big egg on the losing (Halo, -Z) half", show(big and big.Pos))
	check(R.Goose.Act == "Walk", "awake again")
	-- no bouncy egg before 30 s, some after (busy ring: P 13 -> 3 eggs/s)
	local seenBouncy = false
	for _, egg in R.Eggs do if egg.Kind == "Bouncy" then seenBouncy = true end end
	check(not seenBouncy, "no bouncy egg before 30 s")
	for i = 1, 13 do w:Add("P" .. i, "Halo", vec(-8 + i, 3, -50)) end
	w:Until(30)
	check(R.P == 13, "P = Halo / Horns players who may pick inside the ring", R.P)
	local idP = R.NextId
	local bouncy = 0
	local bigs = {}
	local rec = w.Eggs.World.MakeEgg
	w.Eggs.World.MakeEgg = function(egg)
		if egg.Kind == "Bouncy" then bouncy += 1 end
		if egg.Kind == "Big" then table.insert(bigs, { T = w.Now - R.T0, Pos = egg.Pos }) end
		rec(egg)
	end
	w:Until(44)
	check(R.NextId - idP >= 20, "P 13: about 3 eggs per second (the ground cap 30 holds back the rest)", R.NextId - idP)
	check(bouncy >= 2, "bouncy eggs from 30 s", bouncy)
	-- the 30 s nap: the goose is on the +Z half (Horns side) but Halo is behind: the big egg still lands on -Z
	local big30 = nil
	for _, b in bigs do if b.T >= 31.9 and b.T <= 32.5 then big30 = b end end
	check(big30 ~= nil and big30.Pos.Z < 0, "a nap far from the losing half still lays its big egg there", show(big30 and big30.Pos))
	check(w:Ground() <= E.GroundCap + 4, "the ground keeps at most 30 eggs (+ the nap's big egg / feathers)", w:Ground())
	-- the crown at 50 s: max(50, 15% of both totals)
	R.Rescue, R.Poach = 300, 100
	w:Until(50.25)
	local crown
	for _, egg in R.Eggs do if egg.Kind == "Crown" then crown = egg end end
	check(crown ~= nil and crown.Points == 60 and crown.Pos.X < 0, "50 s: a crown egg = max(50, 15% of 400) on the west half", show(crown and { crown.Points, crown.Pos }))
	check(crown and crown.LandAt - (R.T0 + 50) > 0.9, "the crown flies 1 s (nobody picks it as it lands)")
	check(R.Goose.Act == "Lay", "50 s: the goose lays (it walks to the west rim)")
	local stop
	w:Until(55)
	check(R.Goose.Pos.X < 0 and math.abs(R.Goose.Pos.Z) < 1e-6, "the goose stops on the west rim (walked there)", show(R.Goose.Pos))
	stop = R.NextId
	-- ⑤ (최종 검수 10/14): it walks at most Walk.MaxSpeed studs a second, never jumps: pushed 20 studs off, half a second on
	local rim = R.Goose.Pos
	R.Goose.Pos = vec(rim.X, rim.Y, rim.Z + 20)
	w:Until(55.5)
	local back = flat(R.Goose.Pos, rim)
	check(back < 20 and back >= 20 - E.Walk.MaxSpeed * 0.5 - 0.5, "the goose walks back to the rim, never jumps", back)
	w:Until(59.75)
	check(R.NextId == stop, "no egg after 55 s", R.NextId - stop)
	-- the crown is anywhere on the west half (several rounds)
	local east = 0
	for seed = 1, 16 do
		local cw = newWorld({ Live = true, Seed = seed * 7919 })
		cw.Eggs.Begin(cw.Now, "Versus")
		cw:Until(50.25)
		for _, egg in cw.Eggs.Round().Eggs do
			if egg.Kind == "Crown" and egg.Pos.X >= 0 then east += 1 end
		end
	end
	check(east == 0, "16 rounds: every crown egg on the west half", east)
	-- hurry 50-55 s: x1.5 (P 0: 0.9 eggs/s instead of 0.6)
	local q = newWorld({ Live = true })
	q.Eggs.Begin(q.Now, "Versus")
	local Q = q.Eggs.Round()
	q:Until(50.25)
	local h0 = Q.NextId
	q:Until(55)
	check(Q.NextId - h0 >= 4, "50-55 s: 1.5x faster", Q.NextId - h0)
end)

runGroup("drop-spots", function()
	local w = newWorld({ Live = true })
	table.insert(w.Water, { At = vec(25, 0, 20), R = 6 })
	table.insert(w.High, { At = vec(20, 0, -25), R = 5, Y = 5 })
	table.insert(w.Props, { At = vec(-22, 0, 15), R = 3 })
	local spots = {}
	local rec = w.Eggs.World.MakeEgg
	w.Eggs.World.MakeEgg = function(egg) table.insert(spots, egg.Pos); rec(egg) end
	for i = 1, 13 do w:Add("P" .. i, "Halo", vec(-8 + i, 3, -50)) end
	w.Eggs.Begin(w.Now, "Versus")
	w:Until(59.75)
	local bad = {}
	for _, s in spots do
		local why = nil
		if flat(s, E.Center) < 14 then why = "basin" elseif flat(s, E.Center) > 46 then why = "ring" end
		for _, h in E.Home do if flat(s, h) < 16 then why = "home" end end
		for _, a in E.Drop.Avoid do if flat(s, a) < 8 then why = "altar/spawn/pad" end end
		if flat(s, vec(25, 0, 20)) <= 6 then why = "water" end
		if flat(s, vec(20, 0, -25)) <= 5 then why = "step" end
		if flat(s, vec(-22, 0, 15)) <= 3 then why = "prop" end
		if why then table.insert(bad, why .. show(s)) end
	end
	check(#spots >= 60 and #bad == 0, "every laid egg: outside the basin (14), inside 46, 16 from homes, 8 from altar / spawn / pads, no water / step / prop",
		show({ #spots, bad[1], #bad }))
	check(w.Eggs.Round().DropFails > 0, "failed draws are counted (HealthService)", w.Eggs.Round().DropFails)
	local O = {}
	local function ok(x, z) return w.Eggs.SpotOk(x, z, 0, O) end
	check(ok(24, 0) == 0, "a plain spot is fine")
	check(ok(13, 0) == nil and ok(14.5, 0) == 0, "the basin: 14 from the centre")
	check(ok(46.5, 0) == nil and ok(45.5, 0) == 0, "the ring for eggs: 46")
	check(ok(-30, -15) == nil and ok(-30, -13) == 0, "16 from the Knights' nest")
	check(ok(-30, 15) == nil and ok(-30, 13) == 0, "16 from the Horn Legion's cart")
	check(ok(0, 38) == nil and ok(0, 36) == 0, "8 from the altar of fate")
	check(ok(0, -18) == nil and ok(-10, -16) == 0, "8 from the Crossroads spawn")
	check(ok(25, 20) == nil, "never on water")
	check(ok(20, -25) == nil and w.Eggs.SpotOk(20, -25, 2, O) == 5, "a ground step over 4 studs is dropped (3 is fine)")
	check(ok(-22, 15) == nil, "a prop overlap is dropped")
	check(w.Eggs.ClampGoose(vec(5, 0, 0)).X == 16 and w.Eggs.ClampGoose(vec(60, 0, 0)).X == 46, "the goose stays 16..46 from the fountain")
end)
runGroup("chase", function()
	local function world(mode, side, leaderSide)
		local w = newWorld({ Live = true, Edit = function(c)
			local Q = c.Goose.Egg
			Q.Rate = { Base = 0, PerPlayer = 0, Min = 0, Max = 0, Recount = 5 }
			Q.Naps, Q.Sneeze, Q.ArrivalFeathers = {}, 0, 0
		end })
		local h = w:Add("H1", "Halo", vec(30, 3, -20))
		local r = w:Add("R1", "Horns", vec(30, 3, 20))
		w:Begin(mode, side)
		local R = w.Eggs.Round()
		if leaderSide == "Halo" then R.Rescue = 40 elseif leaderSide == "Horns" then R.Poach = 40 end
		local ph, pr = h.Pos, r.Pos
		w:Egg("Gold", vec(30, 0, -20)); w:Egg("Gold", vec(30, 0, -20))
		w:Egg("Gold", vec(30, 0, 20)); w:Egg("Gold", vec(30, 0, 20))
		return w, h, r, ph, pr
	end
	local w, h, r, ph, pr = world("Versus", nil, "Halo")
	local mv = { [h] = ph, [r] = pr }
	w:Until(20.5, mv)
	check(h.Attrs.EggCarry == 2 and r.Attrs.EggCarry == 2, "both carry 2", show({ h.Attrs.EggCarry, r.Attrs.EggCarry }))
	local R = w.Eggs.Round()
	w:Until(21.25, mv)
	check(R.Goose.Act == "Alert" and R.Chase and R.Chase.Target == h, "21 s: '!' over the goose, the leader's carrier is the target",
		show({ R.Goose.Act, R.Chase and R.Chase.Target and R.Chase.Target.Name }))
	local g0 = R.Goose.Pos
	w:Until(21.75, mv)
	check(R.Goose.Pos.X == g0.X and R.Goose.Pos.Z == g0.Z, "the alert second: it stands still")
	local hit = nil
	for _ = 1, 40 do
		w:Step(1, function() w:Jiggle(h, ph); w:Jiggle(r, pr) end)
		if R.Goose.Act == "Chase" then
			local d = flat(R.Goose.Pos, h.Pos)
			check(d <= flat(g0, h.Pos) + 2, "the goose walks toward the target")
		end
		if h.Attrs.EggCarry == 1 then hit = w.Now - R.T0; break end
	end
	check(hit ~= nil and hit <= 26 + 1e-6, "caught within the 4 s chase: the top egg drops", show({ hit, h.Attrs.EggCarry }))
	local dropped = nil
	for _, egg in R.Eggs do dropped = egg end
	check(dropped ~= nil and flat(dropped.Pos, h.Pos) >= 6 - 0.8 and flat(dropped.Pos, h.Pos) <= 8 + 0.8 and dropped.NoPick[h] ~= nil,
		"it bounces 6-8 studs away; its dropper waits 1.5 s", show(dropped and flat(dropped.Pos, h.Pos)))
	check(R.Goose.Act == "Walk" and R.Chase == nil, "one bump per chase, then it walks on")
	check(flat(R.Goose.Pos, E.Center) >= 16 - 1e-6 and flat(R.Goose.Pos, E.Center) <= 46 + 1e-6, "the chasing goose stays 16..46 from the fountain")
	check((r.Attrs.EggCarry or 0) == 2, "the trailing side is never chased")
	-- once per player per round: no second chase of H1 at 38 s (refill H1's hands first)
	w:Egg("Gold", vec(30, 0, -20))
	w:Until(37.25, mv)
	check(not (R.Chase and R.Chase.Target == h), "the same player is chased once per round")
	-- co-op: no chase; a tie: no chase
	local c, ch, _, cph = world("Coop", "Halo", "Halo")
	c:Until(23, { [ch] = cph })
	check(c.Eggs.Round().Chase == nil and c.Eggs.Round().Goose.Act == "Walk", "co-op: no chase")
	local t, th, tr, tph, tpr = world("Versus", nil, nil)
	t:Until(23, { [th] = tph, [tr] = tpr })
	check(t.Eggs.Round().Chase == nil, "a tie: no chase")
end)

runGroup("egg-tag", function()
	local function world()
		local w = newWorld()
		local h = w:Add("H1", "Halo", vec(24, 3, 10))
		local r = w:Add("R1", "Horns", vec(24, 3, 30)) -- far at first
		w:Begin()
		local ph = h.Pos
		w:Egg("Gold", vec(24, 0, 10))
		w:Step(6, function() w:Jiggle(h, ph) end)
		assert(h.Attrs.EggCarry == 1)
		return w, h, r, ph
	end
	local w, h, r, ph = world()
	r.Pos = vec(24, 3, 12) -- 2 studs from the carrier, standing still (never picks)
	w:Step(6, function() w:Jiggle(h, ph) end) -- 0.75 s
	check(h.Attrs.EggCarry == 1, "under 1 s together: nothing")
	w:Step(3, function() w:Jiggle(h, ph) end)
	local tag = w:FxOf("EggTag")[1]
	check((h.Attrs.EggCarry or 0) == 0 and tag and tag.Victim == h.UserId and tag.By == r.UserId, "1 s within 3 studs: the top egg drops (Fx EggTag)",
		show({ h.Attrs.EggCarry, tag }))
	local St = w:St(h)
	check(math.abs((h.Attrs.EggShield or 0) - (St.Shield)) < 1e-9 and St.Shield > w.Now + 2.5, "EggShield = 3 s of protection", show({ h.Attrs.EggShield, w.Now }))
	check((r.Attrs.EggCarry or 0) == 0 and w:Ground() == 1, "the tagger takes nothing: the egg is on the ground")
	-- the dropper waits 1.5 s, then may pick it again
	w:Step(9, function() w:Jiggle(h, ph) end) -- 1.125 s
	check((h.Attrs.EggCarry or 0) == 0, "the dropper cannot re-pick it for 1.5 s")
	w:Step(6, function() w:Jiggle(h, ph) end)
	check(h.Attrs.EggCarry == 1, "after 1.5 s it may", h.Attrs.EggCarry)
	-- the tagger's 4 s cooldown and the victim's shield: no new tag at once
	w:Step(8, function() w:Jiggle(h, ph) end)
	check(h.Attrs.EggCarry == 1, "shield + cooldown: no second tag right away")
	-- a fresh rival waits out the shield (3 s) and then needs 1 s more
	local v, vh, vr, vph = world()
	vr.Pos = vec(24, 3, 12)
	local r2 = v:Add("R2", "Horns", vec(24, 3, 8))
	v:Step(9, function() v:Jiggle(vh, vph) end)
	local t0 = v.Now
	check((vh.Attrs.EggCarry or 0) == 0, "tagged by R1")
	v:Step(16, function() v:Jiggle(vh, vph) end) -- re-picked at ~1.5 s
	check(vh.Attrs.EggCarry == 1 and v.Now - t0 < 3, "re-picked inside the shield")
	v:Step(7, function() v:Jiggle(vh, vph) end) -- ~2.9 s
	check(vh.Attrs.EggCarry == 1, "the shield holds (R2 adjacent)")
	v:Step(20, function() v:Jiggle(vh, vph) end) -- past 3 s + 1 s hold
	local tags, times = {}, {}
	for _, f in v.Fx do if f.Kind == "EggTag" then table.insert(tags, f.Data); table.insert(times, f.T) end end
	check(#tags == 2 and tags[1].By ~= tags[2].By and times[2] - times[1] >= 4 - 1e-6,
		"the other rival tags only after the 3 s shield + its 1 s hold", show({ #tags, times[2] and times[2] - times[1] }))
	local _ = r2
	-- never Neutral, never the same side, never with eggs in hand
	local n, nh, _, nph = world()
	local neu = n:Add("N1", "Neutral", vec(24, 3, 12))
	local mate = n:Add("H2", "Halo", vec(24, 3, 8))
	n:Step(24, function() n:Jiggle(nh, nph) end)
	check(nh.Attrs.EggCarry == 1 and #n:FxOf("EggTag") == 0, "Neutral and teammates never tag", show({ nh.Attrs.EggCarry }))
	local _ = { neu, mate }
end)

runGroup("neutral-and-feathers", function()
	local w = newWorld()
	local n1 = w:Add("N1", "Neutral", vec(24, 3, 0))
	local n2 = w:Add("N2", "Neutral", vec(-24, 3, 0))
	local n3 = w:Add("N3", "Neutral", vec(0, 3, 24))
	local h = w:Add("H1", "Halo", vec(20, 3, 30))
	w:Begin()
	for _ = 1, 3 do w:Egg("Gold", vec(24, 0, 0)); w:Egg("Big", vec(-24, 0, 0)) end
	w:Egg("Big", vec(0, 0, 24))
	w:Egg("Feather", vec(0, 0, 24))
	w:Egg("Feather", vec(20, 0, 30))
	local pos = { [n1] = n1.Pos, [n2] = n2.Pos, [n3] = n3.Pos, [h] = h.Pos }
	w:Step(6, function() for p, at in pos do w:Jiggle(p, at) end end)
	check(w.Bag[n1] and w.Bag[n1].GoldenEgg == 3 and w.Bag[n2].GoldenEgg == 3 and w.Bag[n3].GoldenEgg == 1, "Neutral picks go to the bag as GoldenEgg (any kind)",
		show(w.Bag[n1]))
	check(w.Bag[n3].GooseFeather == 1 and w.Bag[h] and w.Bag[h].GooseFeather == 1 and (h.Attrs.EggCarry or 0) == 0, "a feather goes to the bag (no slot)",
		show({ w.Bag[n3], w.Bag[h] }))
	check((n1.Attrs.EggCarry or 0) == 0 and (n1.Attrs.GooseCount or 0) == 0, "no carrying, no points for Neutral")
	local fx = w:FxOf("EggDeliver")
	local neutralFx = 0
	for _, f in fx do
		if f.Side == "Neutral" and f.N == 1 and f.Points == 0 then neutralFx += 1 end
	end
	check(neutralFx == 0 and #fx == 0, "② no EggDeliver for a Neutral pick (no '+0', no Halo bell): the bag pop says it", show({ neutralFx, #fx }))
	w:Step(40)
	check(w.Eggs.Round().P == 1 and w.Eggs.Round().Presence.Halo > 0, "Neutral never counts in P / N (only H1)", w.Eggs.Round().P)
	local sum = w.Eggs.Finish(w.Now)
	check(w.Bag[n1].GoldenEgg == 4 and w.Bag[n2].GoldenEgg == 4 and w.Bag[n3].GoldenEgg == 1 and sum.NeutralTop[n1] == 1,
		"the top Neutral pickers (a tie: both) get 50% more (floor, at least +1)", show({ w.Bag[n1].GoldenEgg, w.Bag[n2].GoldenEgg, w.Bag[n3].GoldenEgg }))
	local f = newWorld()
	local m = f:Add("M", "Neutral", vec(24, 3, 0))
	f.AllowWarn = { "eggs in 1 s" } -- 5 eggs on one spot in one tick: the > 3 picks / s log (log only)
	f:Begin()
	for _ = 1, 5 do f:Egg("Gold", vec(24, 0, 0)) end
	f:Step(6, function() f:Jiggle(m, vec(24, 3, 0)) end)
	f.Eggs.Finish(f.Now)
	check(f.Bag[m].GoldenEgg == 7, "5 eggs -> +2 (floor of 2.5)", f.Bag[m].GoldenEgg)
	-- a bouncy egg hops 6 studs away from a picker within 7, 3 times at most
	local b = newWorld()
	local bp = b:Add("B", "Halo", vec(SPOT.X - 6.5, 3, 0))
	b:Begin()
	local egg = b:Egg("Bouncy", SPOT)
	local hops = {}
	for _ = 1, 4 do
		local from = egg.Pos
		bp.Pos = vec(egg.Pos.X - 6.5, 3, egg.Pos.Z)
		b:Step(7)
		table.insert(hops, flat(from, egg.Pos))
	end
	check(math.abs(hops[1] - 6) < 1e-6 and math.abs(hops[2] - 6) < 1e-6 and math.abs(hops[3] - 6) < 1e-6 and hops[4] == 0 and egg.Hops == 3,
		"a bouncy egg hops 6 studs, 3 times at most", show(hops))
end)
------------------------------------------------------------------ GooseService (Eggs mode, then the tug)
local function serviceWorld(opts)
	opts = opts or {}
	opts.Service = true
	local w = newWorld(opts)
	function w:STick(n, mover)
		for _ = 1, n or 1 do
			self.Now += TICK
			self.Clock += TICK
			if mover then mover(self) end
			self:Tick()
		end
	end
	-- runs the service until the goose lands (GooseNextAt)
	function w:Land()
		self.Now = self.GS.Attrs.GooseNextAt - TICK
		self:STick(1)
		assert(self.GS.Attrs.GooseActive == true, "the goose landed")
	end
	function w:SUntil(t, mover)
		local T0 = self.Eggs.Round().T0
		while self.GS.Attrs.GooseActive == true and self.Now - T0 < t - 1e-6 do self:STick(1, mover) end
	end
	function w:HonorAdds(p)
		local n = 0
		for _, s in self.Stats do if s.P == p and (s.Key == "Honor" or s.Key == "Infamy") then n += s.N end end
		return n
	end
	function w:NoticeTo(p, text)
		local n = 0
		for _, e in self.Notices do if e.Player == p and e.Text == text then n += 1 end end
		return n
	end
	return w
end

local function kstHour(t) return math.floor(((t + 32400) % 86400) / 3600) end

runGroup("service-schedule", function()
	local w = serviceWorld()
	local now = w.Now
	local nextAt = w.GS.Attrs.GooseNextAt
	check(nextAt > now and nextAt - now <= 14400 and (nextAt + 32400) % 14400 == 0 and kstHour(nextAt) % 4 == 0,
		"the next goose: the next KST 00/04/08/12/16/20 clock time", show({ nextAt - now, kstHour(nextAt) }))
	check(w.GS.Attrs.GooseActive == false and w.GS.Attrs.GooseOvertimeUntil == 0, "idle at start, no overtime")
	w:Land()
	check(w.Eggs.IsActive() and w.Goose.RegisterHit(w:Add("X", "Halo", vec(0, 3, 20)), true) == 0 and w.Goose.GetPosition() == nil,
		"Eggs mode: the hunt runs, hitting the goose counts 0, no swing target")
	w:SUntil(61)
	local after = w.GS.Attrs.GooseNextAt
	check(w.GS.Attrs.GooseActive == false and after - nextAt == 14400, "after the round: the next one 4 hours later", after - nextAt)
	local t = serviceWorld({ Edit = function(c) c.Goose.Schedule.Every = 600 end })
	local n2 = t.GS.Attrs.GooseNextAt
	check((n2 + 32400) % 600 == 0 and n2 - t.Now <= 600, "a test server: Every = 600", n2 - t.Now)
end)

runGroup("service-versus", function()
	local w = serviceWorld({ Edit = function(c) c.Goose.Schedule.Every = 600 end }) -- a test server: one every 10 min
	local h = w:Add("H1", "Halo", vec(-30, 3, -10), 3)
	local r = w:Add("R1", "Horns", vec(-30, 3, 10), 3)
	w:Land()
	check(w.GS.Attrs.GooseMode == "Versus", "both sides: versus")
	local E2 = w.Eggs
	E2.DebugEgg(w.Now, "Gold", vec(-30, 0, -10)); E2.DebugEgg(w.Now, "Gold", vec(-30, 0, -10))
	E2.DebugEgg(w.Now, "Gold", vec(-30, 0, 10))
	local ph, pr = h.Pos, r.Pos
	w:STick(8, function() w:Jiggle(h, ph); w:Jiggle(r, pr) end)
	check(h.Attrs.EggCarry == 2 and r.Attrs.EggCarry == 1, "picks through the service loop", show({ h.Attrs.EggCarry, r.Attrs.EggCarry }))
	local function walk(p, to)
		for _ = 1, 40 do
			w:STick(1, function()
				local d = flat(p.Pos, to)
				local s = math.min(d, 14 * TICK)
				if d > 0 then p.Pos = vec(p.Pos.X + (to.X - p.Pos.X) / d * s, 3, p.Pos.Z + (to.Z - p.Pos.Z) / d * s) end
			end)
		end
	end
	walk(h, vec(-30, 3, -30))
	walk(r, vec(-30, 3, 30))
	check(w.GS.Attrs.GooseRescue == 20 and w.GS.Attrs.GoosePoach == 10, "GameState totals = integer delivery points", show({ w.GS.Attrs.GooseRescue, w.GS.Attrs.GoosePoach }))
	w:SUntil(61, function() w:Jiggle(h, vec(-30, 3, -30)); w:Jiggle(r, vec(-30, 3, 30)) end)
	local fin = w.Finished[#w.Finished]
	check(fin and fin.Result == "Halo" and fin.Info.Mode == "Versus" and fin.Rewarded[h] == 20 and fin.Rewarded[r] == nil,
		"GooseFinished('Halo', { H1 = 20 points }): counts = delivery points of the paid", show(fin and { fin.Result, fin.Info.Mode, fin.Rewarded[h] }))
	check(fin and fin.Info.Delivered == 3 and fin.Info.ScoreGap == 10 and type(fin.Info.H) == "table" and fin.Info.CrownFlip == false,
		"info: Delivered, ScoreGap, H, CrownFlip", show(fin and fin.Info))
	check(#w.War == 1 and w.War[1][1] == "Halo" and w.War[1][2] == 30, "the winning side +30 crown-war points", show(w.War))
	check(w.Gold[h] ~= nil and w.Gold[r] == nil and #w.Paid == 1, "2 eggs paid; 1 egg (10 points) not", show({ w.Gold[h], w.Gold[r] }))
	check(w:NoticeTo(r, w.Config.Goose.Text.BringTwo) == 0 and #w.Notices == 0 and #w.All == 0,
		"A23-191: no toast at all (no start line, no reward / honor / 'bring 2 eggs' line)", show({ #w.Notices, #w.All }))
	check(w.GS.Attrs.GooseResult == "Halo" and w.GS.Attrs.GooseResultHalo == 20 and w.GS.Attrs.GooseResultHorns == 10
		and (w.GS.Attrs.GooseResultUntil or 0) > 0, "② the result stays on GameState (winner + the final bar) until the return",
		show({ w.GS.Attrs.GooseResult, w.GS.Attrs.GooseResultHalo, w.GS.Attrs.GooseResultHorns }))
	local endFx = nil
	for _, f in w.Fx do if f.Kind == "GooseEnd" then endFx = f end end
	check(endFx and endFx.Data and endFx.Data.Halo == 20 and endFx.Data.Horns == 10 and endFx.Data.Winner == "Halo",
		"② GooseEnd carries the final numbers", show(endFx and endFx.Data))
	check(fin and type(fin.Info.Took) == "table" and fin.Info.Took[h] == 2 and fin.Info.Took[r] == 1,
		"④ info.Took: everyone who brought an egg home (paid or not) - the quest count", show(fin and fin.Info.Took))
	local fame = w.Fame[#w.Fame]
	check(fame and fame.P == h and fame.Key == "Honor" and fame.N == 5 and type(fame.Ctx) == "table" and fame.Ctx.RankPoints == 5,
		"the +5 goes through GrantFame with RankPoints 5 (the weekly board, within WeekCap)", show(fame and fame.Ctx))
	check(w:HonorAdds(h) == 5 and h.Data.EggHonorAt == math.floor(w.Now) and w:HonorAdds(r) == 0, "Honor +5 to the paid Knight, EggHonorAt saved",
		show({ w:HonorAdds(h), h.Data.EggHonorAt }))
	check(h.Attrs.GooseCount == 0 and w.GS.Attrs.GooseActive == false and w.GS.Attrs.GooseRescue == 0 and (h.Attrs.EggCarry or 0) == 0,
		"after the end: attributes reset")
	-- the next round within the hour: paid again, no second +5; an hour later: +5 again
	local function round(later)
		if later then
			w.Now += later
			w:STick(1)
		else
			w:Land()
		end
		w.Eggs.DebugEgg(w.Now, "Big", vec(-30, 0, -10))
		local at = vec(-30, 3, -10)
		h.Pos = at
		w:STick(8, function() w:Jiggle(h, at) end)
		walk(h, vec(-30, 3, -30))
		w:SUntil(61, function() w:Jiggle(h, vec(-30, 3, -30)); w:Jiggle(r, vec(-30, 3, 30)) end)
	end
	round()
	check(w.Finished[#w.Finished].Rewarded[h] == 30 and w:HonorAdds(h) == 5, "a big egg alone (30 points) is paid; no second +5 within the hour",
		show({ w.Finished[#w.Finished].Rewarded[h], w:HonorAdds(h) }))
	round(3600)
	check(w:HonorAdds(h) == 10, "an hour later: +5 again", w:HonorAdds(h))
end)

runGroup("service-coop-and-absent", function()
	-- only Knights on the server: co-op, target 80 x ring entrants (min 1)
	local w = serviceWorld()
	local h1 = w:Add("H1", "Halo", vec(70, 3, 0))
	local h2 = w:Add("H2", "Halo", vec(70, 3, 10))
	w:Land()
	check(w.GS.Attrs.GooseMode == "Coop" and w.GS.Attrs.GooseCoopSide == "Halo" and w.GS.Attrs.GooseCoopTarget == 80,
		"co-op; nobody in the ring yet: target 80", show(w.GS.Attrs))
	h1.Pos = vec(20, 3, 0)
	h2.Pos = vec(20, 3, 10)
	w:STick(2)
	check(w.GS.Attrs.GooseCoopTarget == 80 and w.GS.Attrs.GooseCoopPeople == 0, "in the ring but no egg picked: no entrant yet (target 80)",
		show({ w.GS.Attrs.GooseCoopPeople }))
	-- final review 10/12: an entrant = a player who picked an egg this round
	w.Eggs.DebugEgg(w.Now, "Gold", vec(20, 0, 0), 10)
	local p1 = h1.Pos
	w:STick(10, function() w:Jiggle(h1, p1) end)
	check(w.GS.Attrs.GooseCoopTarget == 80 and w.GS.Attrs.GooseCoopPeople == 1, "1 entrant (picked an egg): 80", show({ w.GS.Attrs.GooseCoopPeople }))
	w.Eggs.DebugEgg(w.Now, "Gold", vec(20, 0, 10), 10)
	local p2 = h2.Pos
	w:STick(10, function() w:Jiggle(h2, p2) end)
	check(w.GS.Attrs.GooseCoopTarget == 160 and w.GS.Attrs.GooseCoopPeople == 2, "2 entrants: 160", show({ w.GS.Attrs.GooseCoopTarget }))
	local rival = w:Add("R1", "Horns", vec(24, 3, 0))
	w:STick(2)
	check(rival.Attrs.EggCan == false, "a rival who came late cannot pick")
	w:SUntil(61)
	local fin = w.Finished[#w.Finished]
	check(fin.Result == "Tie" and fin.Info.Mode == "Coop" and fin.Info.Success == false and fin.Info.Target == 160 and #w.War == 0,
		"gauge not filled: a tie, no war points", show(fin.Info))
	-- versus, but the Horn Legion never came into the ring: judged as co-op for the Knights, no war points
	local a = serviceWorld()
	local h = a:Add("H1", "Halo", vec(-30, 3, -10))
	local r = a:Add("R1", "Horns", vec(20, 3, 0)) -- in the ring all round but never picks (an idle alt): still 'never came'
	a:Land()
	check(a.GS.Attrs.GooseMode == "Versus", "both on the server: versus at the start")
	a.Eggs.DebugEgg(a.Now, "Crown", vec(-30, 0, -10), 90)
	local at = h.Pos
	a:STick(8, function() a:Jiggle(h, at) end)
	for _ = 1, 30 do
		a:STick(1, function()
			local to = vec(-30, 3, -30)
			local d = flat(h.Pos, to)
			local s = math.min(d, 14 * TICK)
			if d > 0 then h.Pos = vec(h.Pos.X, 3, h.Pos.Z + (to.Z - h.Pos.Z) / d * s) end
		end)
	end
	a:SUntil(61, function() a:Jiggle(h, vec(-30, 3, -30)) end)
	local af = a.Finished[#a.Finished]
	check(af.Info.Mode == "Coop" and af.Info.NeverCame == "Horns" and af.Info.Side == "Halo" and af.Info.Target == 80 and af.Result == "Halo"
		and #a.War == 0, "a side that never came: the co-op rule (90 >= 80: success at 70%), no war points", show(af.Info))
	local _ = r
end)

-- ③ (최종 검수 10/14): in the square, the mode = who is in it (both sides = versus, one = co-op), live and at the end
runGroup("service-square-mode", function()
	local w = serviceWorld({ Square = true })
	local h = w:Add("H1", "Halo", vec(-30, 3, -10))
	local r = w:Add("R1", "Horns", vec(-30, 3, 10))
	w:Land()
	w:STick(1)
	check(w.GS.Attrs.GooseMode == "Versus" and w.Goose ~= nil, "nobody in the square yet: Pending (shown as the normal bar)", w.GS.Attrs.GooseMode)
	w.Square.In[h] = true
	w:STick(1)
	check(w.GS.Attrs.GooseMode == "Coop" and w.GS.Attrs.GooseCoopSide == "Halo", "a Knight walks in: co-op for the Knights",
		show({ w.GS.Attrs.GooseMode, w.GS.Attrs.GooseCoopSide }))
	w.Square.In[r] = true
	w:STick(2)
	check(w.GS.Attrs.GooseMode == "Versus" and r.Attrs.EggCan ~= false, "a Legion player joins: versus at once, and may pick",
		show({ w.GS.Attrs.GooseMode, r.Attrs.EggCan }))
	w:SUntil(61)
	local fin = w.Finished[#w.Finished]
	check(fin and fin.Info.Mode == "Versus", "the verdict = the bar's versus (both still in the square)", show(fin and fin.Info))
	-- one side only all round: co-op both on the bar and in the verdict
	local c = serviceWorld({ Square = true })
	local k = c:Add("H1", "Halo", vec(-30, 3, -10))
	c:Add("R1", "Horns", vec(70, 3, 10)) -- on the server, never in the square
	c:Land()
	c.Square.In[k] = true
	c:STick(2)
	check(c.GS.Attrs.GooseMode == "Coop", "only Knights in the square: co-op (a Legion player elsewhere does not count)", c.GS.Attrs.GooseMode)
	c:SUntil(61)
	local cf = c.Finished[#c.Finished]
	check(cf and cf.Info.Mode == "Coop" and cf.Info.Side == "Halo" and cf.Info.NeverCame == "Horns", "the verdict: the same co-op",
		show(cf and cf.Info))
end)

runGroup("service-returns-crowd-overtime", function()
	-- faction change / leaving through the service signals
	local w = serviceWorld()
	local h = w:Add("H1", "Halo", vec(24, 3, 0))
	local h2 = w:Add("H2", "Halo", vec(-24, 3, 0))
	w:Add("R1", "Horns", vec(0, 3, 30))
	w:Land()
	w.Eggs.DebugEgg(w.Now, "Gold", vec(24, 0, 0)); w.Eggs.DebugEgg(w.Now, "Gold", vec(-24, 0, 0))
	w:STick(8, function() w:Jiggle(h, vec(24, 3, 0)); w:Jiggle(h2, vec(-24, 3, 0)) end)
	check(h.Attrs.EggCarry == 1 and h2.Attrs.EggCarry == 1, "two carriers")
	h.Faction = "Horns"
	w.Registry.FactionService.FactionChanged:Fire(h)
	check((h.Attrs.EggCarry or 0) == 0, "FactionChanged: the carried eggs go back (dropEntry)")
	w.Registry.PlayerService.PlayerLeaving:Fire(h2)
	check((h2.Attrs.EggCarry or 0) == 0, "PlayerLeaving: the carried eggs go back")
	w.Goose.ReturnEggs(h2, "Travel")
	-- P >= 16: one egg is enough
	local c = serviceWorld()
	local d = c:Add("D", "Halo", vec(-30, 3, -10))
	c:Add("R1", "Horns", vec(30, 3, 0))
	for i = 1, 15 do c:Add("P" .. i, "Halo", vec(-8 + i, 3, -50)) end
	c:Land()
	c.Eggs.DebugEgg(c.Now, "Gold", vec(-30, 0, -10))
	c:STick(8, function() c:Jiggle(d, vec(-30, 3, -10)) end)
	for _ = 1, 30 do
		c:STick(1, function()
			local to = vec(-30, 3, -30)
			local dd = flat(d.Pos, to)
			if dd > 0 then d.Pos = vec(-30, 3, d.Pos.Z + (to.Z - d.Pos.Z) / dd * math.min(dd, 16 * TICK)) end
		end)
	end
	c:SUntil(61, function() c:Jiggle(d, vec(-30, 3, -30)) end)
	local cf = c.Finished[#c.Finished]
	check(cf.Rewarded[d] ~= nil, "17 in the ring (P >= 16): one egg is enough", show(cf.Rewarded))
	-- overtime: GameState GooseOvertimeUntil while a crown egg is carried, 0 after
	local o = serviceWorld()
	local k = o:Add("K", "Halo", vec(-20, 3, -12))
	o:Add("R1", "Horns", vec(20, 3, 12))
	o:Land()
	local T0 = o.Eggs.Round().T0
	o:SUntil(55, function() o:Jiggle(k, vec(-20, 3, -12)) end)
	o.Eggs.DebugEgg(o.Now, "Crown", vec(-20, 0, -12), 50)
	o:SUntil(60.5, function() o:Jiggle(k, vec(-20, 3, -12)) end)
	check(o.GS.Attrs.GooseActive == true and math.abs(o.GS.Attrs.GooseOvertimeUntil - (T0 + 68)) < 1e-6 and o.GS.Attrs.GooseEndsAt == T0 + 60,
		"overtime: GooseOvertimeUntil = end + 8, GooseEndsAt unchanged", show({ o.GS.Attrs.GooseOvertimeUntil - T0, o.GS.Attrs.GooseEndsAt - T0 }))
	o:SUntil(70, function() o:Jiggle(k, vec(-20, 3, -12)) end)
	check(o.GS.Attrs.GooseActive == false and o.GS.Attrs.GooseOvertimeUntil == 0 and (k.Attrs.EggCarry or 0) == 0,
		"after the overtime: the round ends, the crown goes back, nobody keeps eggs")
end)

runGroup("tug-still-works", function()
	local w = serviceWorld({ Mode = "Tug" })
	local h = w:Add("H1", "Halo", vec(0, 3, 0))
	w:Add("R1", "Horns", vec(0, 3, 10))
	w.Goose.DebugStart()
	check(w.GS.Attrs.GooseActive == true and not w.Eggs.IsActive(), "Mode Tug: the tug starts, no egg hunt")
	w.Clock += 1
	check(w.Goose.RegisterHit(h, true) == 2, "a manual hit pulls 2")
	check(w.Goose.GetPosition() ~= nil, "the goose is a swing target again")
end)
-- GROUPS_END

------------------------------------------------------------------ result
local named = {}
for _, key in order do
	local r = results[key]
	table.insert(named, { Group = r.Group, Name = r.Name, Pass = r.Pass, Fail = r.Fail, FirstFailure = r.First })
end
local function enc(v)
	local t = type(v)
	if t == "nil" then return "null" elseif t == "boolean" then return tostring(v)
	elseif t == "number" then return (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c) return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c] or string.format("\\u%04x", string.byte(c)) end) .. '"'
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
	for _, k in keys do table.insert(parts, enc(k) .. ":" .. enc(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end
print("GOLDEN_EGG_RESULT_JSON " .. enc({ Checks = total, Failed = failedCount, Named = named, Findings = findings }))
if failedCount == 0 then print("GOLDEN_EGG_OFFLINE_OK checks=" .. total .. " Studio/API calls=0") end
