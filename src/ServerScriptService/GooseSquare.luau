-- GooseSquare.luau : A23-141 the Goose Square (게임성 개발 2, 2026-10-12). Required ONLY by GooseService (not in the Main
-- lists). The egg hunt runs here, a separate space in the same server outside the map; only players who press Join go.
-- Numbers: Config.Goose.SquareSpace. Client names: Config.Goose.Square (game dev 1's table, read only: Remote, Attr,
-- Block, Text). Contracts: docs/design/goose_square_contract_2026-10-12.md (§6 = this module), the space
-- docs/design/goose_square_skeleton_2026-10-12.md (workspace.GooseSquare, the image team's skeleton).
-- Join: the spot (and its zone) is remembered, auto combat pauses (the attribute only: the saved choice stays), the
-- player is moved to the side's spawn and gets InGooseSquare. Leave (the button, death, leaving the server, a faction
-- change, Travel, falling out, the round's end): the carried eggs go back first (hooks.OnLeave), InGooseSquare off, auto
-- combat back as saved, then (alive, not travelling) the way back = the remembered spot unless it is a PvP spot, under
-- the kill height, inside the square or its zone is gone -> the own town start.
-- Everything that touches the engine goes through GooseSquare.World (the offline test replaces it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local GooseSquare = {}
local TAG = "GooseSquare"
local SP = Config.Goose.SquareSpace
local S = nil
local H = {} -- hooks from GooseService: IsActive() -> bool, OnLeave(p, reason) (the carried eggs go back)
-- In / Back / Auto / Block by player (weak keys: a leaver never stays); Space = the resolved marks
local Q = {
	In = setmetatable({}, { __mode = "k" }),
	Back = setmetatable({}, { __mode = "k" }),
	Auto = setmetatable({}, { __mode = "k" }),
	Block = setmetatable({}, { __mode = "k" }),
	NextBlock = 0,
	Space = nil,
	Joins = 0, -- joins this round (HealthService through GooseFinished info.Joins)
}
local MARKS = { "GooseSpot", "Nest", "Cart", "SpawnHalo", "SpawnHorns", "SpawnNeutral" }

local function client()
	return type(Config.Goose.Square) == "table" and Config.Goose.Square or {}
end
local function attrIn() return client().Attr or "InGooseSquare" end
local function attrBlock() return client().Block or "GooseJoinBlock" end
-- a refusal line from game dev 1's Text table (nil = no line: never an error while that table is not in yet)
local function textOf(key)
	local t = client().Text
	local line = type(t) == "table" and t[key] or nil
	return type(line) == "string" and line ~= "" and line or nil
end

local function call(svc, fn, ...)
	local s = S and S[svc]
	if type(s) ~= "table" or type(s[fn]) ~= "function" then return nil end
	local ok, res = pcall(s[fn], ...)
	if not ok then
		Util.Warn(TAG, svc .. "." .. fn .. ": " .. tostring(res))
		return nil
	end
	return res
end

------------------------------------------------------------------ the engine (replaced by the offline test)
local W = {}
GooseSquare.World = W

function W.Clock() return os.clock() end
function W.Random()
	W.Rng = W.Rng or Random.new()
	return W.Rng:NextNumber()
end
function W.Ready(p) return call("PlayerService", "IsReady", p) == true end
function W.Players()
	local list = call("PlayerService", "GetReadyPlayers")
	return type(list) == "table" and list or {}
end
function W.Alive(p) return Util.IsAlive(p) end
function W.Faction(p)
	local f = call("FactionService", "GetFaction", p)
	return type(f) == "string" and f or "None"
end
-- the kaiju state ("None" when not the kaiju; Queued / Siren / Active all count as the kaiju here)
function W.KaijuState(p)
	local st = call("KaijuService", "GetState", p)
	return type(st) == "string" and st or "None"
end
function W.Sack(p) return call("GrudgeService", "HasSack", p) == true end
-- the PvP combat tag (CombatService.IsInCombat: Config.PvP.CombatTagTime, the same rule Travel uses)
function W.InCombat(p) return call("CombatService", "IsInCombat", p) == true end
-- wanted stars (Config.PvP.NoTravelStars and up may not Travel: never through the square either)
function W.Stars(p)
	local n = call("PvPService", "GetStars", p)
	return tonumber(n) or 0
end
function W.RootCF(p)
	if not Util.IsAlive(p) then return nil end
	local root = Util.GetRoot(p)
	return root and root.CFrame or nil
end
function W.Pivot(p, cf)
	local ch = p.Character
	if not ch then return false end
	call("ZoneService", "MarkTeleported", p, 3) -- the move check never reads the jump as a teleport hack
	local ok, err = pcall(function() ch:PivotTo(cf) end)
	if not ok then Util.Warn(TAG, "PivotTo: " .. tostring(err)) end
	return ok
end
function W.ZoneId(p)
	local z = call("ZoneService", "GetZoneId", p)
	return type(z) == "string" and z or nil
end
function W.ZoneAt(pos) return Config.ZoneAt(pos) end
function W.PvPAt(pos) return Config.PvPAt(pos) end
function W.KillY() return workspace.FallenPartsDestroyHeight end
-- the own town start (Neutral / None: the Crossroads), the way the spawns pick it
function W.TownCF(p)
	local zoneId = Config.HomeZoneId(W.Faction(p))
	local cf = call("ZoneService", "GetSpawnCFrame", zoneId, true)
	if typeof(cf) == "CFrame" then return cf end
	local z = Config.Zones[zoneId] or Config.Zones.Crossroads
	return CFrame.new(z.Spawn + Vector3.new(0, 4, 0))
end
-- the Crossroads start (a wanted player whose spot is gone)
function W.CrossroadsCF()
	local cf = call("ZoneService", "GetSpawnCFrame", "Crossroads", true)
	if typeof(cf) == "CFrame" then return cf end
	return CFrame.new(Config.Zones.Crossroads.Spawn + Vector3.new(0, 4, 0))
end
function W.GetAttr(p, key) return p:GetAttribute(key) end
function W.SetAttr(p, key, value)
	if p.Parent then p:SetAttribute(key, value) end
end
-- the auto-combat choice in the save (Join only paused the attribute)
function W.SavedAuto(p)
	local data = call("PlayerService", "GetData", p)
	return type(data) == "table" and data.AutoCombatEnabled == true
end
function W.Notify(p, text) pcall(Net.Notify, p, text, "bad") end
function W.Model() return workspace:FindFirstChild("GooseSquare") end
local function markPos(m, name)
	local a = m:GetAttribute(name .. "Pos")
	if typeof(a) == "Vector3" then return a end
	local part = m:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then return part.Position end
	if part and part:IsA("Model") then
		local ok, cf = pcall(part.GetPivot, part)
		if ok then return cf.Position end
	end
	return nil
end
-- the marks of a GooseSquare model + its area (the Floor part / model's box)
function W.ReadSpace(m)
	local s = {}
	for _, name in MARKS do s[name] = markPos(m, name) end
	local floor = m:FindFirstChild("Floor", true)
	if floor and floor:IsA("BasePart") then
		s.AreaCF, s.AreaSize = floor.CFrame, floor.Size
	elseif floor and floor:IsA("Model") then
		local ok, cf, size = pcall(function() return floor:GetBoundingBox() end)
		if ok then s.AreaCF, s.AreaSize = cf, size end
	end
	return s
end
-- the plain stand-in when the place has no GooseSquare model yet: a floor, invisible walls and the marks (no decoration)
function W.Build()
	local c, size = SP.Center, SP.Size
	local m = Instance.new("Model")
	m.Name = "GooseSquare"
	m:SetAttribute("BuiltBy", TAG)
	local function part(name, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do p[k] = v end
		p.Parent = m
		return p
	end
	local floor = part("Floor", { Size = size, CFrame = CFrame.new(c - Vector3.new(0, size.Y / 2, 0)),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 232, 215) })
	CollectionService:AddTag(floor, Config.Ground and Config.Ground.Tag or "WalkGround")
	m.PrimaryPart = floor
	local hx, hz, wh = size.X / 2, size.Z / 2, SP.WallHeight
	local walls = {
		Wall_E = { Vector3.new(1, wh, size.Z + 2), Vector3.new(hx + 0.5, wh / 2, 0) },
		Wall_W = { Vector3.new(1, wh, size.Z + 2), Vector3.new(-hx - 0.5, wh / 2, 0) },
		Wall_N = { Vector3.new(size.X + 2, wh, 1), Vector3.new(0, wh / 2, -hz - 0.5) },
		Wall_S = { Vector3.new(size.X + 2, wh, 1), Vector3.new(0, wh / 2, hz + 0.5) },
	}
	for name, w in walls do
		part(name, { Size = w[1], CFrame = CFrame.new(c + w[2]), Transparency = 1, CanQuery = false, CastShadow = false })
	end
	for name, off in SP.Offsets do
		part(name, { Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(c + off + Vector3.new(0, 0.1, 0)), Transparency = 1,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		m:SetAttribute(name .. "Pos", c + off)
	end
	m.Parent = workspace
	return m
end

------------------------------------------------------------------ the space
-- resolves the marks (the place's model wins; none -> the stand-in, built once); a missing mark = Center/GooseSpot + its
-- Config offset. Returns { GooseSpot, Nest, Cart, SpawnHalo, SpawnHorns, SpawnNeutral, AreaCF, AreaSize }
function GooseSquare.Ensure()
	local m = W.Model()
	if not m then
		local ok, built = pcall(W.Build)
		if ok then
			m = built
		else
			Util.Warn(TAG, "the stand-in square failed: " .. tostring(built))
		end
	end
	local s = m and W.ReadSpace(m) or {}
	local c = s.GooseSpot or SP.Center
	for name, off in SP.Offsets do
		if typeof(s[name]) ~= "Vector3" then s[name] = c + off end
	end
	s.GooseSpot = c
	if typeof(s.AreaCF) ~= "CFrame" or typeof(s.AreaSize) ~= "Vector3" then
		s.AreaCF, s.AreaSize = CFrame.new(SP.Center - Vector3.new(0, SP.Size.Y / 2, 0)), SP.Size
	end
	Q.Space = s
	return s
end

function GooseSquare.Space()
	return Q.Space or GooseSquare.Ensure()
end

-- pos is on / over the square's floor (Margin studs of slack sideways, FallBelow under the floor top)
function GooseSquare.Inside(pos)
	if typeof(pos) ~= "Vector3" then return false end
	local s = GooseSquare.Space()
	local rel = s.AreaCF:PointToObjectSpace(pos)
	local top = s.AreaSize.Y / 2
	return math.abs(rel.X) <= s.AreaSize.X / 2 + SP.Margin and math.abs(rel.Z) <= s.AreaSize.Z / 2 + SP.Margin
		and rel.Y >= top - SP.FallBelow
end

------------------------------------------------------------------ join / leave
-- why this player may not join now: "" | "Dead" | "Monster" | "Grudge" | "PvP" (GooseJoinBlock). Final review 10/12: the
-- square must never be a way around Travel's rules - any kaiju state (Queued / Siren / Active), the combat tag
-- (CombatService.IsInCombat, Config.PvP.CombatTagTime) and NoTravelStars wanted stars all block, like Travel
function GooseSquare.BlockOf(p)
	if not W.Alive(p) then return "Dead" end
	if W.KaijuState(p) ~= "None" then return "Monster" end
	if W.Sack(p) then return "Grudge" end
	if W.InCombat(p) or W.Stars(p) >= Config.PvP.NoTravelStars then return "PvP" end
	return ""
end

local function spawnFor(p)
	local s = GooseSquare.Space()
	local f = W.Faction(p)
	local mark = (f == "Halo" and s.SpawnHalo) or (f == "Horns" and s.SpawnHorns) or s.SpawnNeutral
	local a, r = W.Random() * math.pi * 2, W.Random() * SP.SpawnSpread
	local pos = mark + Vector3.new(math.cos(a) * r, 3.5, math.sin(a) * r)
	local look = Vector3.new(s.GooseSpot.X, pos.Y, s.GooseSpot.Z)
	if (look - pos).Magnitude < 0.1 then return CFrame.new(pos) end
	return CFrame.lookAt(pos, look)
end

-- -> true, or false + the refusal key ("Closed" | "Dead" | "Monster" | "Grudge" | "PvP" | nil = no line)
function GooseSquare.Join(p)
	if not (H.IsActive and H.IsActive()) then return false, "Closed" end
	if Q.In[p] or not W.Ready(p) then return false, nil end
	local f = W.Faction(p)
	if f ~= "Halo" and f ~= "Horns" and f ~= "Neutral" then return false, nil end
	local block = GooseSquare.BlockOf(p)
	if block ~= "" then return false, block end
	local cf = W.RootCF(p)
	if not cf then return false, "Dead" end
	Q.Back[p] = { CF = cf, Zone = W.ZoneId(p) }
	if W.GetAttr(p, "AutoCombatEnabled") == true then
		Q.Auto[p] = true
		W.SetAttr(p, "AutoCombatEnabled", false) -- the attribute only: the save keeps the player's choice
	end
	Q.In[p] = true
	Q.Joins += 1
	W.SetAttr(p, attrIn(), true)
	if Q.Block[p] ~= "" then
		Q.Block[p] = ""
		W.SetAttr(p, attrBlock(), "")
	end
	W.Pivot(p, spawnFor(p))
	return true, nil
end

-- the way back: the remembered spot when it is still a fine place, else the own town start. A wanted player
-- (NoTravelStars) always goes back to the spot (or the Crossroads): the square is never a free trip home
function GooseSquare.WayBack(p)
	local b = Q.Back[p]
	local cf = b and b.CF
	if W.Stars(p) >= Config.PvP.NoTravelStars then
		return typeof(cf) == "CFrame" and cf or W.CrossroadsCF()
	end
	if typeof(cf) == "CFrame" then
		local pos = cf.Position
		local zone = W.ZoneAt(pos)
		local zoneOk = b.Zone == nil or (type(zone) == "table" and zone.Id == b.Zone)
		if zoneOk and pos.Y > W.KillY() + SP.KillHeightPad and not GooseSquare.Inside(pos) and not W.PvPAt(pos) then
			return cf
		end
	end
	return W.TownCF(p)
end

-- reason: "Button" | "End" | "Fall" | "Moved" | "Death" | "Left" | "Faction" | "Travel". Moves the player back only
-- when alive and not already going somewhere else (Death / Left / Travel / Moved). -> whether they were inside
function GooseSquare.Leave(p, reason)
	if not Q.In[p] then return false end
	Q.In[p] = nil
	if H.OnLeave then
		local ok, err = pcall(H.OnLeave, p, reason)
		if not ok then Util.Warn(TAG, "OnLeave: " .. tostring(err)) end
	end
	local back = GooseSquare.WayBack(p)
	Q.Back[p] = nil
	if p.Parent then
		W.SetAttr(p, attrIn(), false)
		if Q.Auto[p] then W.SetAttr(p, "AutoCombatEnabled", W.SavedAuto(p)) end
	end
	Q.Auto[p] = nil
	local stay = reason == "Death" or reason == "Left" or reason == "Travel" or reason == "Moved"
	if not stay and p.Parent and W.Alive(p) then W.Pivot(p, back) end
	return true
end

-- everyone inside goes back (the round's end)
function GooseSquare.ReturnAll(reason)
	local list = {}
	for p in Q.In do table.insert(list, p) end
	for _, p in list do GooseSquare.Leave(p, reason or "End") end
	return #list
end

function GooseSquare.IsIn(p) return Q.In[p] == true end

-- the joins since the last call (the round's count for GooseFinished info.Joins)
function GooseSquare.TakeJoins()
	local n = Q.Joins
	Q.Joins = 0
	return n
end

-- the players inside now (a list)
function GooseSquare.Members()
	local list = {}
	for p in Q.In do
		if p.Parent then table.insert(list, p) end
	end
	return list
end

-- every tick: a member off the floor leaves (fell: moved back; carried far away by something else: stays there), a
-- member who became the Active kaiju leaves (the kaiju event moves it), nobody stays once no goose is on (the round's
-- end return failed: a safety net after ReturnAfter + 3 s), and GooseJoinBlock follows every ready player (written only
-- on a change; "" while inside)
function GooseSquare.Tick(_now)
	local out = {}
	if not (H.IsActive and H.IsActive()) and next(Q.In) ~= nil then
		Q.IdleSince = Q.IdleSince or W.Clock()
		if W.Clock() - Q.IdleSince > SP.ReturnAfter + 3 then
			Q.IdleSince = nil
			GooseSquare.ReturnAll("End")
		end
	else
		Q.IdleSince = nil
	end
	for p in Q.In do
		if not p.Parent then
			table.insert(out, { p, "Left" })
		elseif W.KaijuState(p) == "Active" then
			table.insert(out, { p, "Moved" })
		else
			local cf = W.RootCF(p)
			if cf and not GooseSquare.Inside(cf.Position) then
				local s = GooseSquare.Space()
				local far = Vector3.new(cf.Position.X - s.GooseSpot.X, 0, cf.Position.Z - s.GooseSpot.Z).Magnitude > 300
				table.insert(out, { p, far and "Moved" or "Fall" })
			end
		end
	end
	for _, o in out do GooseSquare.Leave(o[1], o[2]) end
	local clock = W.Clock()
	if clock < Q.NextBlock then return end
	Q.NextBlock = clock + SP.BlockEvery
	for _, p in W.Players() do
		local b = Q.In[p] and "" or GooseSquare.BlockOf(p)
		if Q.Block[p] ~= b then
			Q.Block[p] = b
			W.SetAttr(p, attrBlock(), b)
		end
	end
end

-- the remote: exactly one argument "Join" | "Leave"; a refusal is one line (game dev 1's Text key)
function GooseSquare.OnRemote(p, ...)
	if select("#", ...) ~= 1 then return end
	local what = ...
	if what ~= "Join" and what ~= "Leave" then return end
	if not Util.RateLimit(p, "GooseSquare", Config.RateLimits.GooseSquare or 1) then return end
	if what == "Leave" then
		GooseSquare.Leave(p, "Button")
		return
	end
	local ok, key = GooseSquare.Join(p)
	if not ok and key then
		local line = textOf(key)
		if line then W.Notify(p, line) end
	end
end

-- a leaver / a death / a faction change (GooseService connects them); Forget drops the memo of a leaver
function GooseSquare.Forget(p)
	Q.Back[p], Q.Auto[p], Q.Block[p] = nil, nil, nil
end

function GooseSquare.Init(registry, hooks)
	S = registry
	H = type(hooks) == "table" and hooks or {}
end

return GooseSquare
