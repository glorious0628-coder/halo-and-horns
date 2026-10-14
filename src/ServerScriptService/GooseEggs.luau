-- GooseEggs.luau : A23-131 / A23-134 / A23-137 황금 알 줍기, the server rules (게임성 개발 2). Required ONLY by GooseService
-- (not in the Main lists). Contract: docs/design/golden_egg_contract_2026-10-11.md; design docs/design/golden_egg_2026-10-11.md;
-- numbers Config.Goose.Egg.
-- One round: Begin(now, mode, side) -> Step(now, ctx) every Egg.Tick s -> Finish(now) when Step returns "Done".
-- Step's order is fixed: goose -> deliver -> return -> pick (+ tag, bouncy hops, laying) -> end.
-- Ground eggs = anchored parts in workspace.Effects.GooseEggs (attributes Id, Kind, Points, From, LandAt; CFrame = where
-- it lands). Players: EggCarry (slots), GooseCount (my points), EggDelivered (my eggs), EggCan, EggShield, EggPlaza
-- (PlayerService.ComputeWalkSpeed: plaza speed x carry). Fx: EggDeliver / EggReturn / EggTag (to everyone).
-- Everything that touches the engine goes through GooseEggs.World (the offline test replaces it: Step stays pure).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local GooseEggs = {}

local TAG = "GooseEggs"
local E = Config.Goose.Egg
local SIDES = { Halo = "Horns", Horns = "Halo" } -- side -> the other side
local S = nil
local R = { Active = false } -- the round (Begin builds it)
-- A23-141: where the round is played. GooseService sets it from GooseSquare before Begin (SetGeometry): the ring centre
-- (the square's GooseSpot), the two homes (Nest / Cart), the extra no-drop marks (the spawns) and the members (the
-- square's players: only they pick, count, deliver). In the square its walls replace the ring edge (no ring return).
local GEO = { Center = E.Center, Home = { Halo = E.Home.Halo, Horns = E.Home.Horns }, Avoid = nil, AvoidRadius = nil,
	Square = false, Members = nil }
local function inRing(pos)
	if pos == nil then return false end
	if GEO.Square then return true end
	return Vector3.new(pos.X - GEO.Center.X, 0, pos.Z - GEO.Center.Z).Magnitude <= E.RingRadius
end
local lastWarn = {}

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (lastWarn[key] or -math.huge) < 10 then return end
	lastWarn[key] = now
	GooseEggs.World.Warn(tostring(msg))
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

local function setAttr(inst, key, value)
	if inst and inst:GetAttribute(key) ~= value then inst:SetAttribute(key, value) end
end

local function kindDef(kind)
	return E.Kinds[kind] or E.Kinds.Gold
end

local function slotsOf(egg)
	return num(kindDef(egg.Kind).Slots, 1)
end

local function isSide(f)
	return f == "Halo" or f == "Horns"
end

local function call(svc, fn, ...)
	local s = S and S[svc]
	local f = s and s[fn]
	if type(f) ~= "function" then return nil end
	local ok, res = pcall(f, ...)
	if not ok then
		warnThrottled(svc .. fn, svc .. "." .. fn .. " failed: " .. tostring(res))
		return nil
	end
	return res
end

------------------------------------------------------------------ the engine boundary (replaced offline)
local W = {}
GooseEggs.World = W

function W.Warn(msg) Util.Warn(TAG, msg) end
function W.Random()
	W.Rng = W.Rng or Random.new()
	return W.Rng:NextNumber()
end
function W.Players()
	local list = call("PlayerService", "GetReadyPlayers")
	return type(list) == "table" and list or {}
end
function W.Faction(p)
	local f = call("FactionService", "GetFaction", p)
	return type(f) == "string" and f or "None"
end
-- root position of a living character, else nil
function W.RootPos(p)
	if not Util.IsAlive(p) then return nil end
	local root = Util.GetRoot(p)
	return root and root.Position or nil
end
-- a kaiju or a grudge-sack carrier never picks (and counts in no P / N)
function W.Blocked(p)
	local ks = S and S.KaijuService
	if ks and type(ks.GetState) == "function" then
		local ok, st = pcall(ks.GetState, p)
		if ok and st == "Active" then return true end
	end
	return call("GrudgeService", "HasSack", p) == true
end
function W.Plausible(p, pos)
	local zs = S and S.ZoneService
	if not zs or type(zs.IsPlausible) ~= "function" then return true end
	local ok, res = pcall(zs.IsPlausible, p, pos)
	return not ok or res ~= false
end
-- ground height under (x, z) near `pos`, and whether it is water; nil when nothing is hit
function W.Ground(pos)
	local ok, hit = pcall(function()
		local Ground = require(ReplicatedStorage.Shared.Ground)
		return Ground.Cast(pos, 12, 40)
	end)
	if not ok or not hit then return nil end
	return hit.Position.Y, hit.Material == Enum.Material.Water
end
-- a prop (bench, lamp, tree, nest, cart...) overlaps the egg spot
function W.PropHit(pos)
	local ok, hit = pcall(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { Util.GetFolder(workspace, "Effects") }
		local map = workspace:FindFirstChild("Map")
		local ground = map and map:FindFirstChild("Ground")
		if ground then table.insert(skip, ground) end
		local zones = map and map:FindFirstChild("Zones")
		if zones then table.insert(skip, zones) end
		for _, pl in game:GetService("Players"):GetPlayers() do
			if pl.Character then table.insert(skip, pl.Character) end
		end
		params.FilterDescendantsInstances = skip
		for _, part in workspace:GetPartBoundsInRadius(pos + Vector3.new(0, 1.5, 0), E.Drop.Prop, params) do
			if part.CanCollide and part.Transparency < 1 then return true end
		end
		return false
	end)
	return ok and hit == true
end
local function eggFolder()
	return Util.GetFolder(Util.GetFolder(workspace, "Effects"), "GooseEggs")
end
local function placeView(part, egg)
	local h = part.Size.Y
	part.CFrame = CFrame.new(egg.Pos + Vector3.new(0, h / 2, 0))
	part:SetAttribute("From", egg.From)
	part:SetAttribute("LandAt", egg.LandAt)
end
function W.MakeEgg(egg)
	local look = type(Config.GooseEggFx) == "table" and type(Config.GooseEggFx.Kinds) == "table"
		and Config.GooseEggFx.Kinds[egg.Kind] or {}
	local size = num(look.Size, 1.2)
	local part = Instance.new("Part")
	part.Name = egg.Kind == "Feather" and "Feather" or "Egg"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = look.Color or Color3.fromRGB(255, 205, 60)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part:SetAttribute("Id", egg.Id)
	part:SetAttribute("Kind", egg.Kind)
	part:SetAttribute("Points", egg.Points)
	placeView(part, egg)
	part.Parent = eggFolder()
	egg.View = part
end
function W.MoveEgg(egg)
	if egg.View and egg.View.Parent then placeView(egg.View, egg) end
end
function W.RemoveEgg(egg)
	if egg.View then pcall(function() egg.View:Destroy() end) end
	egg.View = nil
end
function W.ClearEggs()
	local effects = workspace:FindFirstChild("Effects")
	local f = effects and effects:FindFirstChild("GooseEggs")
	if f then f:ClearAllChildren() end
end
function W.Fx(kind, data) Net.Fx(nil, kind, data) end
function W.Refresh(p) call("PlayerService", "RefreshSpeed", p) end
function W.Grant(p, id, n, pos) call("LootService", "GrantItems", p, { { Id = id, N = n } }, pos, "Goose") end

------------------------------------------------------------------ per-player state
local function newPlayerState()
	return { Carry = {}, Slots = 0, Points = 0, Delivered = 0, Side = nil, Trail = {}, PickTimes = {}, TagSince = {},
		TagReady = 0, Shield = 0, StillPos = nil, StillAt = 0, LastPickPos = nil, LastPickAt = 0, NeutralEggs = 0,
		Can = nil, Plaza = nil, Chased = false, Pos = nil, Faction = "None" } -- Can / Plaza nil: the first check writes them
end

local function stateOf(p)
	local st = R.Players[p]
	if not st then
		st = newPlayerState()
		R.Players[p] = st
	end
	return st
end

local function heavy(st)
	for _, egg in st.Carry do
		if egg.Kind == "Big" or egg.Kind == "Crown" then return true end
	end
	return false
end

local function publishCarry(p, st)
	setAttr(p, "EggCarry", st.Slots)
	W.Refresh(p)
end

local function headPos(st, i)
	local base = st.Pos or GEO.Center
	return base + v3(0, 3 + (i or 1) * 1.2, 0)
end

------------------------------------------------------------------ drop spots
local function groundOf(pos)
	local y, water = W.Ground(pos)
	return y, water
end

-- (x, z) is a valid egg spot near feet height footY: -> ground y or nil (opts.Half(x, z) = an extra rule)
local function spotOk(x, z, footY, opts)
	local D, c = E.Drop, GEO.Center
	local p = v3(x, footY, z)
	local dc = flat(p, c)
	if dc < D.Fountain or dc > D.Ring then return nil end
	for _, home in GEO.Home do
		if flat(p, home) < D.Home then return nil end
	end
	for _, a in GEO.Avoid or D.Avoid do
		if flat(p, a) < (GEO.AvoidRadius or D.AvoidRadius) then return nil end
	end
	if opts.Half and not opts.Half(x, z) then return nil end
	local y, water = groundOf(p)
	if y == nil or water then return nil end
	if math.abs(y - footY) > D.Step then return nil end
	if W.PropHit(v3(x, y, z)) then return nil end
	return y
end

-- a drop spot around `anchor`: opts { Min, Max, Any (full circle; else the half away from the fountain), Dir (angle),
-- Spread, Half }. nil after Drop.Tries failed draws (each failure counted in R.DropFails)
local function pickSpot(anchor, opts)
	opts = opts or {}
	local D, c = E.Drop, GEO.Center
	local minR, maxR = num(opts.Min, D.Min), num(opts.Max, D.Max)
	local footY = groundOf(anchor) or anchor.Y
	local base, spread = 0, math.pi * 2
	if opts.Dir then
		base, spread = opts.Dir, num(opts.Spread, math.pi / 2)
	elseif not opts.Any and flat(anchor, c) > 0.5 then
		base, spread = math.atan2(anchor.Z - c.Z, anchor.X - c.X), math.pi
	end
	for _ = 1, D.Tries do
		local a = base + (W.Random() - 0.5) * spread
		local r = minR + W.Random() * (maxR - minR)
		local x, z = anchor.X + math.cos(a) * r, anchor.Z + math.sin(a) * r
		local y = spotOk(x, z, footY, opts)
		if y then return v3(x, y, z) end
		R.DropFails += 1
	end
	return nil
end
GooseEggs.SpotOk = spotOk

------------------------------------------------------------------ eggs on the ground
local function groundCount()
	local n = 0
	for _, egg in R.Eggs do
		if egg.Kind ~= "Feather" then n += 1 end
	end
	return n
end

local function addEgg(egg)
	R.Eggs[egg.Id] = egg
	W.MakeEgg(egg)
	return egg
end

-- lays one egg of `kind` from `from` at `spot` (nil spot = drawn around the goose)
local function layEgg(now, kind, opts)
	opts = opts or {}
	local from = R.Goose.Pos
	local spot = opts.Spot or pickSpot(opts.Anchor or from, opts)
	if not spot then return nil end
	R.NextId += 1
	local points = opts.Points or num(kindDef(kind).Points, 10)
	return addEgg({ Id = R.NextId, Kind = kind, Points = math.floor(points + 0.5), Pos = spot, From = from + v3(0, 2, 0),
		LandAt = now + num(opts.Fly, E.FlyTime), Hops = 0, NoPick = {} })
end

local function removeEgg(egg)
	R.Eggs[egg.Id] = nil
	W.RemoveEgg(egg)
end

local function sendReturn(froms)
	if #froms > 0 then pcall(W.Fx, "EggReturn", { Froms = froms }) end
end

-- the carried eggs fly back to the goose. reason for HealthService / the tests
local function returnCarry(p, st, reason, froms)
	if #st.Carry == 0 then return end
	local own = froms == nil
	froms = froms or {}
	for i in st.Carry do table.insert(froms, headPos(st, i)) end
	st.Carry, st.Slots = {}, 0
	R.Returns[reason] = (R.Returns[reason] or 0) + 1
	if p.Parent then publishCarry(p, st) end
	if own then sendReturn(froms) end
end

-- the top carried egg drops near the victim (chase / tag): a valid spot Min..Max away, else at the feet
local function dropTop(now, p, st, minR, maxR)
	local egg = table.remove(st.Carry)
	if not egg then return nil end
	st.Slots = math.max(0, st.Slots - slotsOf(egg))
	publishCarry(p, st)
	local at = st.Pos or GEO.Center
	local spot = pickSpot(at, { Min = minR, Max = maxR, Any = true })
	if not spot then spot = v3(at.X, groundOf(at) or (at.Y - 3), at.Z) end
	egg.From = headPos(st, #st.Carry + 1)
	egg.Pos = spot
	egg.LandAt = now + E.FlyTime
	egg.NoPick = { [p] = now + E.RePick }
	return addEgg(egg)
end

------------------------------------------------------------------ the round's numbers
-- H of a side now: clamp(sqrt(other N / my N), 1, HMax), N = average ring presence; 1 in co-op
local function hFor(side, now)
	if R.Mode == "Coop" or not isSide(side) then return 1 end
	local el = math.max(now - R.T0, E.Tick)
	local mine, other = R.Presence[side] / el, R.Presence[SIDES[side]] / el
	if mine <= 0 or other <= mine then return 1 end
	return math.clamp(math.sqrt(other / mine), 1, E.HMax)
end
GooseEggs.HFor = hFor

local function entrants(side)
	local n = 0
	for _ in R.Entrants[side] or {} do n += 1 end
	return n
end

local function canPick(p, st)
	if not st.Pos or not R.Active then return false end
	local f = st.Faction
	if f == "Neutral" then return true end
	if not isSide(f) or W.Blocked(p) then return false end
	if R.Mode == "Coop" and f ~= R.CoopSide then return false end -- a rival who came late: not this time
	return true
end

-- my root moved MoveMin studs within the last MoveWindow s (the away rule)
local function moved(st, now)
	local trail = st.Trail
	if #trail < 2 or not st.Pos then return false end
	local ref = trail[1]
	for _, s in trail do
		if s.T <= now - E.MoveWindow then ref = s end
	end
	return flat(ref.Pos, st.Pos) >= E.MoveMin
end

local function refreshPlayers(now, dt)
	local seen = {}
	for _, p in (GEO.Members and GEO.Members() or W.Players()) do -- A23-141: the square's members
		seen[p] = true
		local st = stateOf(p)
		local f = W.Faction(p)
		if st.Faction ~= f and #st.Carry > 0 then returnCarry(p, st, "Faction") end
		st.Faction = f
		st.Pos = W.RootPos(p)
		if st.Pos then
			table.insert(st.Trail, { T = now, Pos = st.Pos })
			while #st.Trail > 2 and st.Trail[2].T <= now - E.MoveWindow do table.remove(st.Trail, 1) end
			if not st.StillPos or flat(st.StillPos, st.Pos) >= E.MoveMin then st.StillPos, st.StillAt = st.Pos, now end
		end
		local can = canPick(p, st)
		if can ~= st.Can then
			st.Can = can
			setAttr(p, "EggCan", can)
		end
		if not can and #st.Carry > 0 then returnCarry(p, st, st.Pos and "Blocked" or "Death") end
		local ringIn = inRing(st.Pos)
		if can and ringIn and isSide(f) then
			R.Presence[f] += dt
		end
		local plaza = can and ringIn and now < R.EndsAt + E.Crown.Overtime
		if plaza ~= st.Plaza then
			st.Plaza = plaza
			setAttr(p, "EggPlaza", plaza)
			W.Refresh(p)
		end
	end
	for p, st in R.Players do
		if not seen[p] and (#st.Carry > 0 or st.Can or st.Plaza) then
			returnCarry(p, st, "Leave")
			st.Can, st.Plaza = false, false
			if p.Parent then
				setAttr(p, "EggCan", false)
				setAttr(p, "EggPlaza", false)
				W.Refresh(p)
			end
		end
	end
	if now >= R.NextRecount then
		R.NextRecount = now + E.Rate.Recount
		local n = 0
		for _, st in R.Players do
			if st.Can and isSide(st.Faction) and inRing(st.Pos) then n += 1 end
		end
		R.P = n
		R.PeakP = math.max(R.PeakP, n)
	end
end

------------------------------------------------------------------ the goose
local function clampGoose(pos)
	local c, Wk = GEO.Center, E.Walk
	local d = flat(pos, c)
	if d < 0.01 then return c + v3(Wk.MinFountain, 0, 0) end
	local k = math.clamp(d, Wk.MinFountain, Wk.MaxRing) / d
	return v3(c.X + (pos.X - c.X) * k, c.Y, c.Z + (pos.Z - c.Z) * k)
end
GooseEggs.ClampGoose = clampGoose

local function setAct(act, untilAt)
	R.Goose.Act, R.Goose.ActUntil = act, untilAt
end

-- the side ahead now ("Halo" / "Horns") or nil on a tie / co-op
local function leader()
	if R.Mode == "Coop" then return nil end
	if R.Rescue > R.Poach then return "Halo" end
	if R.Poach > R.Rescue then return "Horns" end
	return nil
end

local function chaseTarget()
	local side = leader()
	if not side then return nil end
	local best, bestSlots, bestD = nil, 0, math.huge
	for p, st in R.Players do
		if st.Faction == side and st.Can and not st.Chased and st.Slots >= E.ChaseMinSlots and st.Pos then
			local d = flat(st.Pos, R.Goose.Pos)
			if st.Slots > bestSlots or (st.Slots == bestSlots and d < bestD) then
				best, bestSlots, bestD = p, st.Slots, d
			end
		end
	end
	return best
end

-- the losing side's half for a nap's big egg (nil on a tie / co-op = anywhere)
local function losingHalf()
	local side = leader()
	if not side then return nil end
	local lose = SIDES[side]
	local hz = GEO.Home[lose].Z - GEO.Center.Z
	return function(_, z) return (z - GEO.Center.Z) * hz > 0 end, lose
end

local function layBig(now)
	local half, lose = losingHalf()
	local egg = layEgg(now, "Big", { Half = half, Any = true })
	if not egg and lose then
		local c = GEO.Center
		local anchor = v3(c.X, c.Y, c.Z + (GEO.Home[lose].Z > c.Z and 25 or -25))
		egg = layEgg(now, "Big", { Half = half, Any = true, Anchor = anchor })
	end
	return egg
end

-- ⑤ (최종 검수 10/14): the goose walks to where it should be at most Walk.MaxSpeed studs a second (no jump to the rim)
local function walkTo(G, target, dt)
	local d = flat(target, G.Pos)
	local step = math.max(0, num(E.Walk.MaxSpeed, 14)) * math.max(0, dt)
	if d <= step or d < 0.01 then
		G.Pos = target
	else
		G.Pos = clampGoose(v3(G.Pos.X + (target.X - G.Pos.X) / d * step, target.Y, G.Pos.Z + (target.Z - G.Pos.Z) / d * step))
	end
end

local function stepGoose(now, el, dt, tilt)
	local G = R.Goose
	-- the crown at Crown.At: the goose stops on the west rim, lays the crown (west half) and Gold eggs
	if el >= E.Crown.At then
		walkTo(G, clampGoose(GEO.Center + v3(-E.Walk.Radius, 0, 0)), dt)
		if not R.CrownLaid then
			R.CrownLaid = true
			setAct("Lay", R.T0 + E.Duration)
			local pts = math.max(E.Crown.Min, math.floor(E.Crown.Share * (R.Rescue + R.Poach) + 0.5))
			local c = GEO.Center
			local west = function(x) return x < c.X end
			local crown = layEgg(now, "Crown", { Points = pts, Any = true, Fly = E.CrownFly, Anchor = c, Min = E.Drop.Fountain,
				Max = E.Drop.Ring, Half = west }) or layEgg(now, "Crown", { Points = pts, Any = true, Fly = E.CrownFly, Half = west })
			R.CrownPoints = crown and crown.Points or 0
			for _ = 1, E.Crown.Gold do layEgg(now, "Gold") end
		end
		return
	end
	-- naps (a feather when it dozes off, a big egg on the losing half when it wakes)
	for i, t in E.Naps do
		if el >= t and not R.NapDone[i] then
			R.NapDone[i] = "Nap"
			setAct("Nap", R.T0 + t + E.NapTime)
			for _ = 1, E.NapFeathers do layEgg(now, "Feather", { Any = true }) end
		end
		if R.NapDone[i] == "Nap" and el >= t + E.NapTime then
			R.NapDone[i] = true
			setAct("Walk", 0)
			layBig(now)
		end
	end
	if G.Act == "Nap" and now < G.ActUntil then return end
	-- chases (versus only; once per player per round)
	local ch = R.Chase
	for i, t in E.Chases do
		if not R.ChaseDone[i] and el >= t - E.ChaseAlert then
			R.ChaseDone[i] = true
			local target = R.Mode == "Versus" and chaseTarget() or nil
			if target then
				R.Players[target].Chased = true
				ch = { Target = target, Start = R.T0 + t, Until = R.T0 + t + E.ChaseTime }
				R.Chase = ch
				setAct("Alert", ch.Start)
			end
		end
	end
	if ch then
		local st = R.Players[ch.Target]
		if not st or not st.Pos or #st.Carry == 0 or now >= ch.Until or not inRing(st.Pos) then
			R.Chase = nil
			setAct("Walk", 0)
		elseif now >= ch.Start then
			setAct("Chase", ch.Until)
			local d = flat(st.Pos, G.Pos)
			local step = math.min(d, E.ChaseSpeed * dt)
			if d > 0.01 then
				G.Pos = clampGoose(v3(G.Pos.X + (st.Pos.X - G.Pos.X) / d * step, G.Pos.Y, G.Pos.Z + (st.Pos.Z - G.Pos.Z) / d * step))
			end
			if flat(st.Pos, G.Pos) <= E.ChaseHit then
				local b = E.ChaseBounce
				dropTop(now, ch.Target, st, b[1], b[2])
				R.Chase = nil
				setAct("Walk", 0)
			end
			return
		else
			return -- the "!" second: it stands still
		end
	end
	if G.Act ~= "Walk" then setAct("Walk", 0) end
	-- the walk: a circle around the fountain, its centre tilted toward the losing side
	G.Angle += dt * math.pi * 2 / E.Walk.Lap
	local c = GEO.Center
	walkTo(G, clampGoose(v3(c.X + math.cos(G.Angle) * E.Walk.Radius, c.Y, c.Z + num(tilt, 0) + math.sin(G.Angle) * E.Walk.Radius)), dt)
end

------------------------------------------------------------------ deliver / return / pick / tag / lay
local function deliver(now, p, st)
	local side = st.Faction
	local home = GEO.Home[side]
	local n, pts, crown = 0, 0, false
	for _, egg in st.Carry do
		n += 1
		pts += egg.Points
		if egg.Kind == "Crown" then crown = true end
	end
	-- cheat check: the walk from the last pick spot to the ring edge at the carrying speed (x slack) minus a grace
	local speed = Config.GooseEggSpeed(st.Slots, heavy(st))
	local need = math.max(0, flat(st.LastPickPos or home, home) - E.HomeRadius) / (speed * E.Cheat.SpeedSlack) - E.Cheat.Grace
	if now - st.LastPickAt < need then
		R.CheatLogs += 1
		W.Warn(string.format("egg delivery too fast: %s %.2f s < %.2f s", tostring(p.Name), now - st.LastPickAt, need))
		if E.Cheat.Enforce == true then
			returnCarry(p, st, "Cheat")
			return
		end
	end
	local add = math.floor(pts * hFor(side, now) + 0.5)
	local mineBefore, otherBefore = R.Rescue, R.Poach
	if side == "Horns" then mineBefore, otherBefore = R.Poach, R.Rescue end
	if side == "Halo" then R.Rescue += add else R.Poach += add end
	if crown and mineBefore <= otherBefore and mineBefore + add > otherBefore then R.CrownFlip = side end
	st.Points += add
	st.Delivered += n
	R.Delivered += n
	st.Carry, st.Slots = {}, 0
	setAttr(p, "GooseCount", st.Points)
	setAttr(p, "EggDelivered", st.Delivered)
	publishCarry(p, st)
	if R.Chase and R.Chase.Target == p then
		R.Chase = nil
		setAct("Walk", 0)
	end
	pcall(W.Fx, "EggDeliver", { UserId = p.UserId, Pos = home, N = n, Points = add, Side = side })
end

local function fits(st, egg)
	if egg.Kind == "Feather" then return true end
	-- ③ (Codex, 최종 검수 10/14): an artisan never takes the crown egg (the sides' last big swing)
	if st.Faction == "Neutral" then return egg.Kind ~= "Crown" end
	local slots = slotsOf(egg)
	if slots >= E.MaxSlots then return st.Slots == 0 end
	return st.Slots + slots <= E.MaxSlots
end

local function pick(now, p, st, egg)
	removeEgg(egg)
	local times = st.PickTimes
	table.insert(times, now)
	while times[1] and now - times[1] > 1 do table.remove(times, 1) end
	if #times > E.PickRateLog then
		R.FastPicks += 1
		warnThrottled("rate" .. tostring(p.UserId), string.format("%s picked %d eggs in 1 s", tostring(p.Name), #times))
	end
	if st.Faction == "Neutral" then -- A23-134: straight to the bag, no points, never in P / N / H / co-op
		if egg.Kind == "Feather" then
			W.Grant(p, E.Items.Feather, 1, egg.Pos)
		else
			W.Grant(p, E.Items.Egg, 1, egg.Pos)
			st.NeutralEggs += 1 -- ② no EggDeliver Fx (it drew "+0" and the Halo bell): the bag pop is the feedback
		end
		return
	end
	if egg.Kind == "Feather" then
		W.Grant(p, E.Items.Feather, 1, egg.Pos)
		return
	end
	-- final review 10/12: a side's entrant = a player who picked an egg this round (the co-op target, 'a side never
	-- came'): an idle alt who only joined never turns a co-op round into a versus one
	if isSide(st.Faction) then R.Entrants[st.Faction][p] = true end
	table.insert(st.Carry, egg)
	st.Slots += slotsOf(egg)
	st.LastPickPos, st.LastPickAt = egg.Pos, now
	st.StillPos, st.StillAt = st.Pos, now
	publishCarry(p, st)
end

local function pickAll(now)
	local pairs_ = {}
	local reach, high = E.PickRadius + E.PickSlack, E.PickHeight + E.PickSlack
	for p, st in R.Players do
		if st.Can and st.Pos and moved(st, now) then
			for _, egg in R.Eggs do
				if now >= egg.LandAt and (egg.NoPick[p] or 0) <= now then
					local d = flat(egg.Pos, st.Pos)
					if d <= reach and math.abs(st.Pos.Y - egg.Pos.Y) <= high then
						table.insert(pairs_, { P = p, St = st, Egg = egg, D = d })
					end
				end
			end
		end
	end
	-- nearest pair first; equal distance = fewer deliveries this round, then the lower UserId (fixed)
	table.sort(pairs_, function(a, b)
		if a.D ~= b.D then return a.D < b.D end
		if a.St.Delivered ~= b.St.Delivered then return a.St.Delivered < b.St.Delivered end
		if a.P.UserId ~= b.P.UserId then return a.P.UserId < b.P.UserId end
		return a.Egg.Id < b.Egg.Id
	end)
	local plausible = {}
	for _, pr in pairs_ do
		local egg, st, p = pr.Egg, pr.St, pr.P
		if R.Eggs[egg.Id] == egg and fits(st, egg) then
			if plausible[p] == nil then plausible[p] = W.Plausible(p, st.Pos) end
			if plausible[p] then pick(now, p, st, egg) end
		end
	end
end

-- A23-134 egg tag: an empty-handed rival within Radius for Hold s drops the carrier's top egg (never Neutral)
local function tagAll(now)
	local T = E.Tag
	if type(T) ~= "table" or T.On ~= true then return end
	for v, vs in R.Players do
		if vs.Shield > now then -- a shielded carrier: nobody's hold time runs
			for _, ts in R.Players do ts.TagSince[v] = nil end
		elseif #vs.Carry > 0 and isSide(vs.Faction) and vs.Pos then
			for t, ts in R.Players do
				local rival = ts.Can and isSide(ts.Faction) and ts.Faction ~= vs.Faction and #ts.Carry == 0 and ts.Pos
				if rival and ts.TagReady <= now and flat(ts.Pos, vs.Pos) <= T.Radius then
					ts.TagSince[v] = ts.TagSince[v] or now
					if now - ts.TagSince[v] >= T.Hold - 1e-6 then
						ts.TagSince[v] = nil
						ts.TagReady = now + T.Cooldown
						vs.Shield = now + T.Shield
						setAttr(v, "EggShield", vs.Shield)
						local pos = vs.Pos
						dropTop(now, v, vs, 2, 4)
						R.Tags += 1
						pcall(W.Fx, "EggTag", { Victim = v.UserId, By = t.UserId, Pos = pos })
						break
					end
				else
					ts.TagSince[v] = nil
				end
			end
		end
	end
end

-- a bouncy egg hops away (Hop studs) from the nearest picker within Near, Hops times at most
local function hopAll(now)
	local B = E.Bouncy
	for _, egg in R.Eggs do
		if egg.Kind == "Bouncy" and egg.Hops < B.Hops and now >= egg.LandAt then
			local near, nd = nil, B.Near
			for _, st in R.Players do
				if st.Can and st.Pos then
					local d = flat(st.Pos, egg.Pos)
					if d <= nd then near, nd = st, d end
				end
			end
			if near then
				local dir = math.atan2(egg.Pos.Z - near.Pos.Z, egg.Pos.X - near.Pos.X)
				local spot = pickSpot(egg.Pos, { Min = B.Hop, Max = B.Hop, Dir = dir, Spread = math.pi / 2 })
				if spot then
					egg.From, egg.Pos, egg.LandAt = egg.Pos, spot, now + E.FlyTime
					egg.Hops += 1
					W.MoveEgg(egg)
				end
			end
		end
	end
end

local function layAll(now, el, dt)
	if el >= E.LayStop or el >= E.Crown.At and not R.CrownLaid then return end
	if R.Goose.Act == "Nap" then return end
	local rate = math.clamp(E.Rate.Base + E.Rate.PerPlayer * R.P, E.Rate.Min, E.Rate.Max)
	if el >= E.Hurry.From and el < E.Hurry.To then rate *= E.Hurry.Mult end
	R.LayAcc += rate * dt
	while R.LayAcc >= 1 do
		R.LayAcc -= 1
		if groundCount() < E.GroundCap then
			local kind = (el >= E.Bouncy.From and W.Random() < E.Bouncy.Share) and "Bouncy" or "Gold"
			layEgg(now, kind)
		end
	end
end

local function crownCarried()
	for _, st in R.Players do
		for _, egg in st.Carry do
			if egg.Kind == "Crown" then return true end
		end
	end
	return false
end

local function returnGround(now, all)
	local froms = {}
	for _, egg in R.Eggs do
		if all or (now >= egg.LandAt and now - egg.LandAt >= E.Unpicked) then
			table.insert(froms, egg.Pos)
			removeEgg(egg)
			R.Returns.Ground = (R.Returns.Ground or 0) + 1
		end
	end
	sendReturn(froms)
end

------------------------------------------------------------------ public
function GooseEggs.Init(registry)
	S = registry
end

-- a new round. mode = "Versus" | "Coop" | "Pending", side = the co-op side
-- A23-141: the square's geometry (GooseService, before Begin): g = { Center, Home = { Halo, Horns }, Avoid = { pos },
-- AvoidRadius, Square = true, Members = function() -> { Player } }; nil = back to the Config ring (the old plaza)
function GooseEggs.SetGeometry(g)
	g = type(g) == "table" and g or {}
	local h = type(g.Home) == "table" and g.Home or {}
	GEO.Center = g.Center or E.Center
	GEO.Home = { Halo = h.Halo or E.Home.Halo, Horns = h.Horns or E.Home.Horns }
	GEO.Avoid = type(g.Avoid) == "table" and g.Avoid or nil
	GEO.AvoidRadius = tonumber(g.AvoidRadius)
	GEO.Square = g.Square == true
	GEO.Members = type(g.Members) == "function" and g.Members or nil
end
function GooseEggs.Geometry() return GEO end

function GooseEggs.Begin(now, mode, side)
	GooseEggs.Cleanup()
	R = { Active = true, T0 = now, EndsAt = now + E.Duration, LastStep = now, Mode = mode or "Versus", CoopSide = side or "None",
		Eggs = {}, NextId = 0, Players = {}, Rescue = 0, Poach = 0, Presence = { Halo = 0, Horns = 0 },
		Entrants = { Halo = {}, Horns = {} }, P = 0, PeakP = 0, NextRecount = now, LayAcc = 0, NapDone = {}, ChaseDone = {},
		Chase = nil, CrownLaid = false, CrownPoints = 0, CrownFlip = nil, Overtime = 0, Ended = false, DropFails = 0,
		Returns = {}, CheatLogs = 0, FastPicks = 0, Tags = 0, Delivered = 0,
		Goose = { Pos = clampGoose(GEO.Center + v3(E.Walk.Radius, 0, 0)), Angle = 0, Act = "Walk", ActUntil = 0 } }
	refreshPlayers(now, 0)
	for p in R.Players do
		setAttr(p, "GooseCount", 0)
		setAttr(p, "EggDelivered", 0)
		setAttr(p, "EggShield", 0)
	end
	-- the arrival sneeze: eggs fanned over the half away from the fountain (the basin side has no spots), and feathers
	local g, c = R.Goose.Pos, GEO.Center
	local away = math.atan2(g.Z - c.Z, g.X - c.X)
	for i = 1, E.Sneeze do
		layEgg(now, "Gold", { Dir = away + ((i - 0.5) / E.Sneeze - 0.5) * math.pi, Spread = 0.4 })
	end
	for _ = 1, E.ArrivalFeathers do layEgg(now, "Feather", { Any = true }) end
end

function GooseEggs.SetMode(mode, side)
	if not R.Active then return end
	R.Mode, R.CoopSide = mode or R.Mode, side or R.CoopSide
end

-- one server check. ctx = { Tilt = studs toward +Z (GooseService.sideOffset) }. -> "Done" when the round is over
function GooseEggs.Step(now, ctx)
	if not R.Active then return nil end
	local el = now - R.T0
	local dt = math.clamp(now - R.LastStep, 0, 1)
	R.LastStep = now
	refreshPlayers(now, dt)
	stepGoose(now, el, dt, type(ctx) == "table" and ctx.Tilt or 0)
	-- 1 deliver
	for p, st in R.Players do
		if #st.Carry > 0 and isSide(st.Faction) and st.Can and st.Pos and flat(st.Pos, GEO.Home[st.Faction]) <= E.HomeRadius then
			deliver(now, p, st)
		end
	end
	-- 2 return (ring edge, death, standing still; ground eggs nobody picked)
	local froms = {}
	for p, st in R.Players do
		if #st.Carry > 0 then
			if not st.Pos then
				returnCarry(p, st, "Death", froms)
			elseif not inRing(st.Pos) then
				returnCarry(p, st, "Ring", froms)
			elseif now - st.StillAt >= E.IdleReturn then
				returnCarry(p, st, "Idle", froms)
			end
		end
	end
	sendReturn(froms)
	if el < E.Duration then
		returnGround(now, false)
		-- 3 pick (+ tag, hops, laying)
		pickAll(now)
		tagAll(now)
		hopAll(now)
		layAll(now, el, dt)
		return nil
	end
	-- 4 end: ground eggs go back; a carried crown egg holds the round open up to Crown.Overtime s
	if not R.Ended then
		R.Ended = true
		returnGround(now, true)
		if crownCarried() then R.Overtime = R.EndsAt + E.Crown.Overtime end
	end
	if R.Overtime > 0 and now < R.Overtime and crownCarried() then return nil end
	return "Done"
end

-- ends the round: carried eggs return, attributes reset, the top Neutral picker's bonus. -> the round's summary
function GooseEggs.Finish(_now)
	if not R.Active then return nil end
	local froms = {}
	local sum = { Points = {}, Delivered = {}, Side = {}, Rescue = R.Rescue, Poach = R.Poach,
		Entrants = { Halo = entrants("Halo"), Horns = entrants("Horns") }, PeakP = R.PeakP, CrownFlip = R.CrownFlip,
		CrownPoints = R.CrownPoints, DropFails = R.DropFails, Returns = R.Returns, CheatLogs = R.CheatLogs,
		FastPicks = R.FastPicks, Tags = R.Tags, DeliveredTotal = R.Delivered, NeutralTop = {}, Neutral = {},
		H = { Halo = hFor("Halo", R.LastStep), Horns = hFor("Horns", R.LastStep) } }
	local top = 0
	for p, st in R.Players do
		returnCarry(p, st, "End", froms)
		if isSide(st.Faction) and (st.Points > 0 or st.Delivered > 0) then
			sum.Points[p], sum.Delivered[p], sum.Side[p] = st.Points, st.Delivered, st.Faction
		end
		if st.NeutralEggs > 0 then
			sum.Neutral[p] = st.NeutralEggs
			top = math.max(top, st.NeutralEggs)
		end
	end
	sendReturn(froms)
	-- A23-134: the round's top Neutral picker(s) get 50% more eggs (floor, at least +1)
	if top > 0 then
		for p, n in sum.Neutral do
			if n == top and p.Parent then
				local bonus = math.max(1, math.floor(n * (E.NeutralTopMult - 1)))
				W.Grant(p, E.Items.Egg, bonus, nil)
				sum.NeutralTop[p] = bonus
			end
		end
	end
	for p, st in R.Players do
		if p.Parent then
			setAttr(p, "EggCarry", 0)
			setAttr(p, "EggCan", false)
			setAttr(p, "EggPlaza", false)
			setAttr(p, "EggShield", 0)
			W.Refresh(p)
		end
		st.Carry = {}
	end
	for _, egg in R.Eggs do W.RemoveEgg(egg) end
	R = { Active = false }
	pcall(W.ClearEggs)
	return sum
end

-- a carrier's eggs go back now (pads / Travel, faction change, leave). Safe any time
function GooseEggs.ReturnEggs(p, reason)
	if not R.Active then return end
	local st = R.Players[p]
	if st then returnCarry(p, st, reason or "Travel") end
end

-- the player left: eggs back, state dropped (what they delivered stays in the totals; a ring entrant stays counted)
function GooseEggs.Leave(p)
	if not R.Active then return end
	local st = R.Players[p]
	if not st then return end
	returnCarry(p, st, "Leave")
	if R.Chase and R.Chase.Target == p then R.Chase = nil end
	R.Players[p] = nil
end

-- faction change: eggs back and a fresh entry (no points kept for the old side)
function GooseEggs.DropEntry(p)
	if not R.Active then return end
	local st = R.Players[p]
	if not st then return end
	returnCarry(p, st, "Faction")
	R.Entrants.Halo[p], R.Entrants.Horns[p] = nil, nil
	R.Players[p] = nil
	if p.Parent then
		setAttr(p, "GooseCount", 0)
		setAttr(p, "EggDelivered", 0)
	end
end

-- (pcall'd by GooseService at finish AND at server start): no egg left on the ground, nobody slowed by eggs
function GooseEggs.Cleanup()
	pcall(W.ClearEggs)
	local players = {}
	pcall(function() players = game:GetService("Players"):GetPlayers() end)
	for _, p in players do
		pcall(function()
			if p:GetAttribute("EggCarry") ~= 0 or p:GetAttribute("EggPlaza") == true then
				p:SetAttribute("EggCarry", 0)
				p:SetAttribute("EggPlaza", false)
				W.Refresh(p)
			end
		end)
	end
end

function GooseEggs.IsActive() return R.Active == true end
function GooseEggs.GoosePos() return R.Active and R.Goose.Pos or nil end
function GooseEggs.Act() if R.Active then return R.Goose.Act, R.Goose.ActUntil end return nil, 0 end
function GooseEggs.OvertimeUntil() return R.Active and R.Overtime or 0 end
function GooseEggs.Totals() if R.Active then return R.Rescue, R.Poach end return 0, 0 end
function GooseEggs.Entrants(side) return R.Active and entrants(side) or 0 end
-- for the offline test: the live round (never write it outside this module)
function GooseEggs.Round() return R end
-- for tests / Studio checks: one egg of `kind` landed at `pos` now (points = the kind's unless given)
function GooseEggs.DebugEgg(now, kind, pos, points, landAt)
	if not R.Active then return nil end
	return layEgg(now, kind, { Spot = pos, Points = points, Fly = (landAt or now) - now })
end

return GooseEggs
