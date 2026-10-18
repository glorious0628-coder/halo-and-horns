-- ZoneService.luau : zone tracking, level gates, enemy-town bounce, Travel remote, teleport pads, spawn CFrames.
--
-- Zones are XZ rectangles from Config (Config.ZoneAt); the current zone of every ready player is cached here and
-- mirrored to the attributes ZoneId / ZonePvP / ZoneTown. Addendum A3-L1 + A6: a Halo/Horns/Neutral player standing in a
-- faction town that is not theirs (Neutral: either faction town) is bounced to the Crossroads spawn
-- (kaiju and sack carriers too; the sack keeps its state). "None" (no faction chosen yet) is not bounced.
-- An Active kaiju may enter no faction town at all (not even its own): Halo is bounced out of HornsTown, so a kaiju
-- waiting there could never be reached; it is bounced to Crossroads, where Halo can still hit it.
-- A10: a player below Y = -20 (fell under the Terrain world) is teleported to their home spawn.
-- CR-H2: the zone loop also sanity-checks movement (IsPlausible / validateMove, Config.AntiCheat). LOG-ONLY while
-- Config.AntiCheat.Enforce is false: suspicious moves are logged, never pulled back or refused. Server teleports call
-- MarkTeleported first. Pad touches always need the root on the pad (enforced regardless of Enforce) and are
-- movement-checked before the pad teleport clears the track. The A10 rescue first checks the drop against free fall.
-- CR-L18: a Travel channel carries a token; the zone loop cancels it at once (damage / combat / sack / kaiju / stars /
-- death) and a stale channel timer never finishes a newer channel.
-- zone_check_halo #11 / #62 / #63 (검수 2026-10-10): a live player whose root stays in Terrain water for
-- Config.WaterRescue.Seconds in a row in a town zone or within Margin studs of a town rect is moved to the nearest dry
-- land (waterTick, after the gates); nothing dry nearby -> the A10 home spawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local ZoneService = {}

ZoneService.ZoneChanged = Util.Signal.new() -- (player, newZoneId, oldZoneId)

local TAG = "ZoneService"
local DEFAULT_ZONE = "Crossroads"
local SPAWN_JITTER = 6 -- random XZ offset in [-6, 6]
local SPAWN_LIFT = 4 -- spawn CFrame is 4 studs above the ground
local GATE_NOTIFY_INTERVAL = 3 -- NeedLevel / enemy-town toast at most once per 3 s
local WARN_INTERVAL = 10
local MAX_DEST_LENGTH = 64
local RESCUE_Y = -20 -- addendum A10: below this (anywhere) -> home spawn
-- 최종 검수 10/17 (r9: a root at Y -1e6 in one step = a NaN / broken CFrame, never a real fall): a position with NaN / inf
-- or below this goes back to the last good spot instead
local ABSURD_Y = -1e4
local ENEMY_TOWN_FALLBACK = "You can't enter the other side's town!" -- used only if Config.Text.EnemyTown is missing
local KAIJU_TOWN_FALLBACK = "A Kaiju can't enter towns!" -- used only if Config.Text.KaijuNoTown is missing

local S = nil
local zoneIds = {} -- [Player] = cached zone id
local pvpNow = {} -- [Player] = PvP where the player stood at the last zone sample (A23-90: zone PvP or a PvP area)
local pvpNoteAt = {} -- [Player] = os.clock() of the last entered-PvP line (검수 10/09: the pit's edge is crossed often)
local PVP_NOTE_GAP = 20
local lastGateNotify = {} -- [Player] = os.clock() of the last bounce toast
local lastPadTouch = {} -- [Player] = os.clock() of the last handled pad touch
local hookedPads = setmetatable({}, { __mode = "k" }) -- [BasePart] = true
local lastWarnAt = {}
local channels = {} -- [Player] = { Token = {}, Start = os.clock() } of the running Travel channel (CR-L18)

-- CR-H2 movement check state (log-only unless Config.AntiCheat.Enforce)
local AC = Config.AntiCheat or {}
local move = {
	lastGood = {}, -- [Player] = { Pos = Vector3, T = os.clock(), Char = Model, VY = Y speed of the last interval }
	graceUntil = {}, -- [Player] = os.clock() until which every move is accepted (server teleport / spawn)
	extra = {}, -- [Player] = { Studs, Until }: SKL-3 Hop, that many more flat studs until Until (AllowMove)
	lastLog = {}, -- [Player] = os.clock() of the last suspicious-move log
}

-- "Home" plus every real zone id listed in Config.Travel.Destinations
local validDestinations = {}
for _, d in Config.Travel.Destinations do
	if d.Id ~= "Home" and Config.Zones[d.Id] then
		validDestinations[d.Id] = true
	end
end

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarnAt[key]
	if last and now - last < WARN_INTERVAL then return end
	lastWarnAt[key] = now
	Util.Warn(TAG, msg)
end

local function fmt(key, ...)
	local s = Config.Text[key]
	if type(s) ~= "string" then return nil end
	return string.format(s, ...)
end

local function notify(player, text, kind, sound)
	if type(text) == "string" and text ~= "" then
		Net.Notify(player, text, kind, nil, sound)
	end
end

local function getFaction(player)
	if S and S.FactionService then
		return S.FactionService.GetFaction(player)
	end
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function getLevel(player)
	return tonumber(player:GetAttribute("Level")) or 1
end

local function kaijuState(player)
	local ks = S.KaijuService and S.KaijuService.GetState(player)
	return type(ks) == "string" and ks or "None"
end

local function isKaiju(player)
	local ks = kaijuState(player)
	return ks == "Siren" or ks == "Active"
end

local function hasSack(player)
	return S.GrudgeService ~= nil and S.GrudgeService.HasSack(player) == true
end

local function getStars(player)
	local n = S.PvPService and S.PvPService.GetStars(player)
	return tonumber(n) or 0
end

local function inCombat(player)
	return S.CombatService ~= nil and S.CombatService.IsInCombat(player) == true
end

local function lastDamagedAt(player)
	local t = S.CombatService and S.CombatService.GetLastDamagedAt(player)
	return tonumber(t) or 0
end

-- Being hit / fighting only stops Travel where players can fight players (anti-escape). In a no-PvP zone
-- (meadow, towns) a slime's bite no longer cancels the trip home; kaiju / sack / stars rules still apply.
local function combatBlocksTravel(player, start)
	local zoneId = zoneIds[player] or DEFAULT_ZONE
	-- Outskirts touch the PvP woods: a fight that spills out of them still blocks the escape there (A23-90: where
	-- PvP is on now, so the ruins' safe ring is like the meadow)
	if pvpNow[player] ~= true and zoneId ~= "Outskirts" then return false end
	return lastDamagedAt(player) >= start or inCombat(player)
end

------------------------------------------------------------------ movement check (CR-H2)
local function acNum(key, default)
	local v = AC[key]
	return (type(v) == "number" and v == v) and v or default
end

-- every move is accepted for `seconds` (default AntiCheat.TeleportGrace) and the next sample starts a new track
local function markTeleported(player, seconds)
	local s = tonumber(seconds)
	if not s or s ~= s or s < 0 then
		s = acNum("TeleportGrace", 1)
	end
	move.graceUntil[player] = os.clock() + math.min(s, 30)
	move.lastGood[player] = nil
end

-- (ok, flat, rise, allowFlat, allowRise): pos against the last good sample. Flat move <= WalkSpeed * MoveMult * dt + Slack,
-- rise <= RisePerSec * dt + RiseSlack; falling is never limited. No sample / new character / grace -> ok.
local function checkMove(player, pos)
	local g = move.lastGood[player]
	if not g or g.Char ~= player.Character then return true end
	local now = os.clock()
	if now < (move.graceUntil[player] or 0) then return true end
	local hum = Util.GetHumanoid(player)
	local speed = hum and hum.WalkSpeed or Config.Player.WalkSpeed
	local dt = math.max(now - g.T, 0.05)
	local flat = Util.FlatDistance(pos, g.Pos)
	local rise = pos.Y - g.Pos.Y
	local allowFlat = speed * acNum("MoveMult", 1.6) * dt + acNum("Slack", 8)
	local extra = move.extra[player]
	if extra and now < extra.Until then allowFlat += extra.Studs end -- SKL-3 Hop (AllowMove)
	local allowRise = acNum("RisePerSec", 60) * dt + acNum("RiseSlack", 12)
	return flat <= allowFlat and rise <= allowRise, flat, rise, allowFlat, allowRise
end

-- CR-H2 (A10 rescue): (ok, drop, allowDrop). Drop since the last good sample <= free fall that starts with the last
-- sampled sink speed (+ one tick of gravity) + FallSlack. No sample / new character / grace -> ok.
local function checkFall(player, pos)
	local g = move.lastGood[player]
	if not g or g.Char ~= player.Character then return true end
	local now = os.clock()
	if now < (move.graceUntil[player] or 0) then return true end
	local grav = workspace.Gravity
	if type(grav) ~= "number" or grav ~= grav or grav <= 0 then
		grav = 196.2
	end
	local dt = math.max(now - g.T, 0.05)
	local sink = math.max(-(g.VY or 0), 0) + grav * dt
	local drop = g.Pos.Y - pos.Y
	local allowDrop = sink * dt + 0.5 * grav * dt * dt + acNum("FallSlack", 30)
	return drop <= allowDrop, drop, allowDrop
end

-- at most once per AntiCheat.LogCooldown s per player
local function logSuspicious(player, where, flat, rise, allowFlat, allowRise, extra)
	local now = os.clock()
	local last = move.lastLog[player]
	if last and now - last < acNum("LogCooldown", 10) then return end
	move.lastLog[player] = now
	Util.Warn(TAG, string.format("CR-H2 suspicious move (%s, %s): %s (%d) flat %.1f/%.1f rise %.1f/%.1f zone %s%s",
		tostring(where), AC.Enforce == true and "enforced" or "log only", player.Name, player.UserId,
		flat or 0, allowFlat or 0, rise or 0, allowRise or 0, tostring(zoneIds[player]), extra or ""))
end

-- Enforce only: back to the last good position; the track continues from there at rest
local function pullBack(root, g)
	root.CFrame = CFrame.new(g.Pos) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	g.T = os.clock()
	g.VY = 0
end

-- zone-loop part: records the last good sample. A suspicious move is logged; only with Enforce it is pulled back
-- to the last good position (returns false: the rest of the zone update is skipped).
local function validateMove(player, root)
	local now, pos = os.clock(), root.Position
	local ok, flat, rise, allowFlat, allowRise = checkMove(player, pos)
	local g = move.lastGood[player]
	if not ok then
		logSuspicious(player, "zone", flat, rise, allowFlat, allowRise)
		if AC.Enforce == true and g then
			pullBack(root, g)
			return false
		end
	end
	local char = player.Character
	if g and g.Char == char then
		g.VY = (pos.Y - g.Pos.Y) / math.max(now - g.T, 0.05) -- sink speed for checkFall
		g.Pos = pos
		g.T = now
	else
		move.lastGood[player] = { Pos = pos, T = now, Char = char, VY = 0 }
	end
	return true
end

-- A10 rescue part: a drop below RESCUE_Y faster than free fall (or a flat hop) is logged BEFORE teleport() clears
-- the track. Only with Enforce it is pulled back to the last good position instead (returns false: no rescue).
local function validateRescue(player, root)
	local pos = root.Position
	local okMove, flat, rise, allowFlat, allowRise = checkMove(player, pos)
	local okFall, drop, allowDrop = checkFall(player, pos)
	if okMove and okFall then return true end
	logSuspicious(player, "rescue", flat, rise, allowFlat, allowRise,
		string.format(" drop %.1f/%.1f", drop or 0, allowDrop or 0))
	local g = move.lastGood[player]
	if AC.Enforce == true and g then
		pullBack(root, g)
		return false
	end
	return true
end

-- 최종 검수 10/17: a position no real move can reach - NaN / inf in any axis or Y below ABSURD_Y
function ZoneService.Absurd(pos)
	if typeof(pos) ~= "Vector3" then return true end
	for _, v in { pos.X, pos.Y, pos.Z } do
		if v ~= v or v == math.huge or v == -math.huge then return true end
	end
	return pos.Y < ABSURD_Y
end

-- pivots the character to a zone spawn; false when there is no character / root
local function teleport(player, zoneId)
	-- A23-141: any teleport leaves the Goose Square first (the carried eggs go back; no move back, this is the move)
	local gs = S.GooseService
	if type(gs) == "table" and type(gs.LeaveSquare) == "function" then
		local okL, errL = pcall(gs.LeaveSquare, player, "Travel")
		if not okL then Util.Warn(TAG, "LeaveSquare: " .. tostring(errL)) end
	end
	local character = Util.GetCharacter(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	markTeleported(player) -- CR-H2: the jump to the spawn is not a suspicious move
	character:PivotTo(ZoneService.GetSpawnCFrame(zoneId))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function notifyBounce(player, text)
	if not text then return end
	local now = os.clock()
	local last = lastGateNotify[player]
	if last and now - last < GATE_NOTIFY_INTERVAL then return end
	lastGateNotify[player] = now
	notify(player, text, "bad")
end

-- bounce toast text when the player may not stand in this faction town, else nil.
-- A3-L1 / A6: a faction town that is not the player's own; "None" (no side chosen yet) is never bounced.
-- An Active kaiju: every faction town (see header).
local function forbiddenTownText(player, zone)
	if not zone.Town or zone.Faction == nil then return nil end
	if kaijuState(player) == "Active" then
		return fmt("KaijuNoTown") or KAIJU_TOWN_FALLBACK
	end
	local f = getFaction(player)
	if f == "None" or f == zone.Faction then return nil end
	return fmt("EnemyTown") or ENEMY_TOWN_FALLBACK
end

-- CR-L18: true when a running Travel channel must stop (the finishChannel conditions, checked every zone tick)
local function channelBroken(player, ch)
	return not Util.IsAlive(player)
		or combatBlocksTravel(player, ch.Start)
		or hasSack(player)
		or isKaiju(player)
		or getStars(player) >= Config.PvP.NoTravelStars
end

-- CR-L18: drops the channel (its timer sees a missing token), clears the bar, tells the player
local function cancelChannel(player)
	if not channels[player] then return end
	channels[player] = nil
	if player.Parent then
		player:SetAttribute("TravelingUntil", 0)
		notify(player, fmt("TravelCancelled"), "bad", "None") -- cut short by a hit: happens to me, no Deny
	end
end

-- the zone / PvP bookkeeping of one zone-loop sample at `pos` in `zone`: attributes, the entered-PvP / safe lines and
-- ZoneChanged (A23-90: a function of its own so its rules are tested offline)
local function applyZone(player, zone, pos)
	local old = zoneIds[player] or DEFAULT_ZONE
	-- A23-90: PvP follows the position (a PvP zone, or a PvP area inside a zone: the ruins' Crown Pit), so crossing the
	-- pit's edge inside the ruins changes it too
	local pvp = Config.PvPAt(pos, zone)
	local wasPvP = pvpNow[player] == true
	if zone.Id == old and pvp == wasPvP then return end
	if zone.Id ~= old then
		zoneIds[player] = zone.Id
		player:SetAttribute("ZoneId", zone.Id)
		player:SetAttribute("ZoneTown", zone.Town == true)
	end
	pvpNow[player] = pvp
	player:SetAttribute("ZonePvP", pvp)
	if pvp and not wasPvP and os.clock() - (pvpNoteAt[player] or -math.huge) >= PVP_NOTE_GAP then
		pvpNoteAt[player] = os.clock()
		-- A23-130: the Artisan Guild is immune to PvP, so no line for it (EnteredPvPNeutral off; the HUD chip says it)
		if getFaction(player) ~= "Neutral" then
			notify(player, fmt("EnteredPvP"), "bad", "None") -- happens to me: no Deny
		end
	end -- (leaving PvP: no line; the HUD chip shows it. 'Safe zone.' deleted, 최종 검수 10/15)
	if zone.Id ~= old then ZoneService.ZoneChanged:Fire(player, zone.Id, old) end
end

------------------------------------------------------------------ water rescue (zone_check_halo #11 / #62 / #63)
-- 검수 2026-10-10: a live player whose root stays in Terrain water for Config.WaterRescue.Seconds in a row inside a town
-- zone (Zones[*].Town: Crossroads, Halo Citadel, Horns Den) or within Margin studs of a town rect is moved to the nearest
-- dry land (the Halo canal walls are too steep to climb out of; the A10 rescue only fires below Y -20).
-- "In water" is read from the Terrain, never from the client's Humanoid state: the water surface of the root's voxel
-- column is at most RootSlack studs below the root (a swimmer floats at the surface; a foot-deep spring basin stays under
-- the root). A dry spell shorter than DryReset s (a swim jump at a wall) keeps the count; a longer one, leaving the town
-- area, a new character or a rescue restarts it. Dry land = rings of rays straight down (Terrain + workspace.Map only, so
-- characters, monsters and pets are never hit; water NOT ignored, so a wet spot answers Water; non-colliding parts
-- ignored) whose hit is Terrain / Map.Ground / a Map.Decor "Bridge_*" deck, DryAbove..MaxRise above the water, at most
-- MaxSlope steep, not an AvoidMaterials floor, with no collidable Map part in the body box above it, in a zone the player
-- may stand in (level gate, enemy town, Active kaiju). Nearest ring first, then the lowest climb. None -> the A10 home
-- spawn (an Active kaiju: Crossroads). waterProbe.Surface / Ground / Clear are the only engine calls (the offline test
-- swaps them).
local water = {} -- [Player] = { Char = Model, Since = os.clock() of the first wet sample | nil, DrySince = number | nil, NextAt }
local waterProbe = { Params = nil, Overlap = nil, ParamsAt = -math.huge }

local function wrNum(key, default)
	local v = (Config.WaterRescue or {})[key]
	return (type(v) == "number" and v == v) and v or default
end

-- the town zone whose XZ rect grown by Margin holds pos, else nil (a seasonal zone counts only in season, like ZoneAt)
local function nearTown(pos)
	local margin = wrNum("Margin", 40)
	for _, id in Config.ZoneOrder do
		local z = Config.Zones[id]
		if z and z.Town == true and (z.Season == nil or Config.SeasonOn(z.Season))
			and math.abs(pos.X - z.Center.X) <= z.Size.X / 2 + margin
			and math.abs(pos.Z - z.Center.Z) <= z.Size.Z / 2 + margin then
			return z
		end
	end
	return nil
end

-- one value of a 1 x 3 x 1 voxel array ([x][y][z], as ReadVoxelChannels / ReadVoxels return them), or nil
local function voxel(a, j)
	return type(a) == "table" and type(a[1]) == "table" and type(a[1][j]) == "table" and a[1][j][1] or nil
end

-- the Terrain water surface Y in the 4-stud voxel column at pos (the root's voxel, one below, one above), or nil when
-- none of them holds water: the highest wet voxel's bottom + 4 x its water occupancy (how tools/worldkit/halo_terrain.luau
-- writes WaterTop). Water = LiquidOccupancy (shorelines), or SolidMaterial Water with its SolidOccupancy (shorelines off,
-- like halo_terrain's readSummary); ReadVoxels is the fallback. An engine error reads as "no water".
function waterProbe.Surface(pos)
	local terrain = workspace.Terrain
	if not terrain then return nil end
	local r = 4
	local x0, y0, z0 = math.floor(pos.X / r) * r, math.floor(pos.Y / r) * r - r, math.floor(pos.Z / r) * r
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + r, y0 + 3 * r, z0 + r))
	local liquid, mats, occs = nil, nil, nil
	local okC, ch = pcall(function()
		return terrain:ReadVoxelChannels(region, r, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	end)
	if okC and type(ch) == "table" and type(ch.LiquidOccupancy) == "table" then
		liquid, mats, occs = ch.LiquidOccupancy, ch.SolidMaterial, ch.SolidOccupancy
	else
		local okV, m, o = pcall(function()
			return terrain:ReadVoxels(region, r)
		end)
		if not okV or type(m) ~= "table" or type(o) ~= "table" then return nil end
		mats, occs = m, o
	end
	local top = nil
	for j = 1, 3 do
		local occ = tonumber(voxel(liquid, j)) or 0
		if voxel(mats, j) == Enum.Material.Water then occ = math.max(occ, tonumber(voxel(occs, j)) or 0) end
		if occ > 0.02 then top = y0 + (j - 1) * r + r * math.min(occ, 1) end
	end
	return top
end

-- the ray / overlap params (Terrain + workspace.Map + "WalkGround"-tagged floors outside it; water NOT ignored;
-- non-colliding parts ignored) and the walking-ground roots (Config.GroundRoots, the rule MonsterService and the clients'
-- Ground.luau use), rebuilt every 5 s so a MapBuilder.Rebuild() (a new workspace.Map) or a new tag is picked up
local function waterParams()
	local now = os.clock()
	if waterProbe.Params and now - waterProbe.ParamsAt < 5 then return waterProbe.Params, waterProbe.Overlap end
	local map = workspace:FindFirstChild("Map")
	local tagged = Util.Tagged((Config.Ground or {}).Tag or "WalkGround")
	local roots = {}
	for _, inst in Config.GroundRoots(workspace.Terrain, map, tagged) do roots[inst] = true end
	waterProbe.Roots = roots
	local list = map and { workspace.Terrain, map } or { workspace.Terrain }
	for _, inst in tagged do
		local node, inMap = inst, false
		while node ~= nil and not inMap do
			inMap = map ~= nil and node == map
			node = node.Parent
		end
		if not inMap then table.insert(list, inst) end -- a tagged floor outside workspace.Map is seen too
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	params.IgnoreWater = false
	pcall(function() params.RespectCanCollide = true end)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = map and { map } or {}
	pcall(function() overlap.RespectCanCollide = true end)
	-- query as a PLAYER: A23-81 decor (balustrades, lanterns, statues, tree posts) is in Config.Player.DecorGroup, which
	-- does not collide with Default, so a Default-group ray / box would look straight through it
	local group = (Config.Player or {}).CollisionGroup or "Players"
	local okG, registered = pcall(function()
		return game:GetService("PhysicsService"):IsCollisionGroupRegistered(group)
	end)
	if okG and registered == true then
		pcall(function() params.CollisionGroup = group end)
		pcall(function() overlap.CollisionGroup = group end)
	end
	waterProbe.Params, waterProbe.Overlap, waterProbe.ParamsAt = params, overlap, now
	return params, overlap
end

-- true when a ray hit is walking ground: Terrain or a part inside one of the roots waterParams() keeps (Config.GroundRoots:
-- workspace.Map.Ground, the bridges, "WalkGround"-tagged floors). Roofs, props, walls and travel pads are never landing
-- spots.
local function walkableHit(inst)
	if typeof(inst) ~= "Instance" then return false end
	if inst:IsA("Terrain") then return true end
	local roots = type(waterProbe.Roots) == "table" and waterProbe.Roots or {}
	local node = inst
	while node ~= nil and node ~= workspace do
		if roots[node] then return true end
		node = node.Parent
	end
	return false
end

-- the first hit straight down from origin: { Position, NormalY, Material, Walkable } or nil (nothing / an engine error)
function waterProbe.Ground(origin, length)
	local params = waterParams()
	local ok, hit = pcall(function()
		return workspace:Raycast(origin, Vector3.new(0, -length, 0), params)
	end)
	if not ok or not hit then return nil end
	return { Position = hit.Position, NormalY = hit.Normal.Y, Material = hit.Material, Walkable = walkableHit(hit.Instance) }
end

-- true when no collidable workspace.Map part's bounding box overlaps the body box (size) centred at center
function waterProbe.Clear(center, size)
	local _, overlap = waterParams()
	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap)
	end)
	return ok and type(parts) == "table" and #parts == 0
end

-- true for a floor the rescue never lands on (Config.WaterRescue.AvoidMaterials, e.g. the Horns lava strips)
local function avoidFloor(material)
	for _, name in (Config.WaterRescue or {}).AvoidMaterials or {} do
		local ok, m = pcall(function() return Enum.Material[name] end)
		if ok and m == material then return true end
	end
	return false
end

-- a landing spot the zone loop would not bounce the player out of again (level gate, enemy town, Active kaiju in a town)
local function allowedAt(player, spot)
	local zone = Config.ZoneAt(spot)
	return getLevel(player) >= zone.MinLevel and forbiddenTownText(player, zone) == nil
end

-- the nearest dry ground point around pos for a body whose root stands `stand` studs above its feet, or nil
local function findDryLand(player, pos, surface, stand, width)
	local WR = Config.WaterRescue
	local top = math.max(pos.Y, surface) + wrNum("RayTop", 60)
	local length = top - surface + 4 -- down past the water surface (a wet spot answers Water)
	local minY, maxY = surface + wrNum("DryAbove", 0.5), surface + wrNum("MaxRise", 30)
	local minNormal = math.cos(math.rad(wrNum("MaxSlope", 40)))
	local n = math.clamp(math.floor(wrNum("RaysPerRing", 12)), 4, 32)
	local box = Vector3.new(width, stand * 2, width)
	for _, radius in (type(WR.Rings) == "table" and WR.Rings or { 8, 16, 32, 64 }) do
		local best, bestRise = nil, math.huge
		for i = 0, n - 1 do
			local a = 2 * math.pi * i / n
			local hit = waterProbe.Ground(Vector3.new(pos.X + radius * math.cos(a), top, pos.Z + radius * math.sin(a)), length)
			local y = hit and hit.Position.Y
			if hit and hit.Walkable == true
				and hit.Material ~= Enum.Material.Water
				and y >= minY
				and y <= maxY
				and hit.NormalY >= minNormal
				and y - surface < bestRise
				and not avoidFloor(hit.Material)
				and allowedAt(player, hit.Position)
				and waterProbe.Clear(hit.Position + Vector3.new(0, 0.5 + stand, 0), box) then
				best, bestRise = hit.Position, y - surface
			end
		end
		if best then return best end
	end
	return nil
end

-- out of the water: onto the nearest dry land facing inland (CR-H2 grace first), else the A10 home spawn
-- nothing dry nearby: the spawn of the town whose area the swimmer is in when the player may stand there, else the
-- Crossroads (the other side's town, an Active kaiju): never a free trip to a far home town
local function fallbackZone(player, pos)
	local town = nearTown(pos)
	if town and getLevel(player) >= town.MinLevel and forbiddenTownText(player, town) == nil then return town.Id end
	return DEFAULT_ZONE
end

local function rescueFromWater(player, root, surface)
	local character = Util.GetCharacter(player)
	if not character then return end
	local hum = Util.GetHumanoid(player)
	local size = typeof(root.Size) == "Vector3" and root.Size or Vector3.new(2, 2, 1)
	local stand = (hum and tonumber(hum.HipHeight) or 2) + size.Y / 2
	if hum and hum.RigType == Enum.HumanoidRigType.R6 then -- R6: HipHeight 0, the legs carry the root (PlayerService standingHeight)
		local leg = character:FindFirstChild("Left Leg")
		stand += (leg and leg:IsA("BasePart")) and leg.Size.Y or 2
	end
	stand = math.max(stand, 1)
	local pos = root.Position
	local spot = findDryLand(player, pos, surface, stand, math.max(size.X * 1.5, 3))
	if spot then
		local at = spot + Vector3.new(0, math.max(stand + 0.5, wrNum("Lift", 4)), 0)
		local away = Vector3.new(spot.X - pos.X, 0, spot.Z - pos.Z)
		markTeleported(player) -- CR-H2: the move to the shore is not a suspicious move
		character:PivotTo(away.Magnitude > 0.5 and CFrame.lookAt(at, at + away) or CFrame.new(at))
		root.AssemblyLinearVelocity = Vector3.zero
	else
		teleport(player, fallbackZone(player, pos))
	end
	if Config.WaterRescue.Toast ~= false then
		notify(player, fmt("WaterRescue"), "info", "None") -- happens to me: no sound
	end
end

-- the zone-loop part (after the gates): samples the water every CheckEvery s and rescues after Seconds in a row
local function waterTick(player, root)
	local WR = Config.WaterRescue
	if type(WR) ~= "table" or WR.Enabled == false then return end
	local now, char = os.clock(), player.Character
	local st = water[player]
	if not st or st.Char ~= char then
		st = { Char = char, NextAt = now }
		water[player] = st
	end
	if now < st.NextAt then return end
	st.NextAt = now + wrNum("CheckEvery", 0.5)
	local pos = root.Position
	local surface = nearTown(pos) and waterProbe.Surface(pos) or nil
	if type(surface) ~= "number" or surface < pos.Y - wrNum("RootSlack", 1) then
		-- dry here (or away from the towns): a short dry spell keeps the count, a longer one restarts it
		if st.Since and not st.DrySince then st.DrySince = now end
		if st.DrySince and now - st.DrySince >= wrNum("DryReset", 1.5) then st.Since, st.DrySince = nil, nil end
		return
	end
	st.DrySince = nil
	st.Since = st.Since or now
	if now - st.Since < wrNum("Seconds", 8) then return end
	st.Since = nil
	rescueFromWater(player, root, surface)
end

-- the zone-loop body (also run on CharacterSpawned and right after a teleport)
local function updateZone(player)
	if not S.PlayerService.IsReady(player) then return end
	local ch = channels[player]
	if ch and channelBroken(player, ch) then
		cancelChannel(player) -- CR-L18: at once, not when the 3 s bar runs out
	end
	if not Util.IsAlive(player) then return end
	local root = Util.GetRoot(player)
	if not root then return end
	if ZoneService.Absurd(root.Position) then
		-- 최종 검수 10/17: never a real fall: back to the last good spot of this character (else the home spawn below)
		local g = move.lastGood[player]
		local character = Util.GetCharacter(player)
		if g and character and g.Char == character and not ZoneService.Absurd(g.Pos) and g.Pos.Y >= RESCUE_Y then
			local back = g.Pos
			markTeleported(player)
			character:PivotTo(CFrame.new(back))
			root.AssemblyLinearVelocity = Vector3.zero
			-- the spot stays the last good one (markTeleported cleared the track): a second broken step goes back here too
			move.lastGood[player] = { Pos = back, T = os.clock(), Char = character, VY = 0 }
			return
		end
	end
	if root.Position.Y < RESCUE_Y or ZoneService.Absurd(root.Position) then
		if not ZoneService.Absurd(root.Position) and not validateRescue(player, root) then return end -- CR-H2 (pulled back only with AntiCheat.Enforce)
		-- 최종 검수 10/17 (detail audit #10): on the King's rematch row a fall gets up where a KO there would (FirstKOService.GetUp:
		-- by Fizzby), never the long walk from the home town
		local fk = S.FirstKOService
		local okU, up = pcall(function() return type(fk) == "table" and type(fk.GetUp) == "function" and fk.GetUp(player) or nil end)
		local character = Util.GetCharacter(player)
		if okU and type(up) == "table" and typeof(up.CFrame) == "CFrame" and character then
			markTeleported(player)
			character:PivotTo(up.CFrame)
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end
		-- A10 rescue (an Active kaiju goes to Crossroads directly: it may not stand in its home town)
		local home = (kaijuState(player) == "Active") and DEFAULT_ZONE or Config.HomeZoneId(getFaction(player))
		teleport(player, home)
		return
	end
	if not validateMove(player, root) then return end -- CR-H2 (pulled back only with AntiCheat.Enforce)
	local zone = Config.ZoneAt(root.Position)

	if getLevel(player) < zone.MinLevel then
		teleport(player, DEFAULT_ZONE)
		notifyBounce(player, fmt("NeedLevel", zone.MinLevel))
		return
	end
	local townText = forbiddenTownText(player, zone)
	if townText then
		teleport(player, DEFAULT_ZONE)
		notifyBounce(player, townText)
		return
	end

	applyZone(player, zone, root.Position)
	-- zone_check_halo #62: the water rescue in its own pcall (a probe error never stops the zone loop)
	local okW, errW = pcall(waterTick, player, root)
	if not okW then warnThrottled("water", "water rescue error: " .. tostring(errW)) end
end

local function cleanup(player)
	zoneIds[player] = nil
	pvpNow[player] = nil -- A23-90
	pvpNoteAt[player] = nil
	lastGateNotify[player] = nil
	lastPadTouch[player] = nil
	channels[player] = nil -- CR-L18
	water[player] = nil -- water rescue (zone_check_halo #62)
	move.lastGood[player] = nil -- CR-H2
	move.graceUntil[player] = nil
	move.lastLog[player] = nil
	move.extra[player] = nil
end

------------------------------------------------------------------ public API
function ZoneService.GetZoneId(player)
	return zoneIds[player] or DEFAULT_ZONE
end

function ZoneService.GetZone(player)
	return Config.Zones[ZoneService.GetZoneId(player)] or Config.Zones[DEFAULT_ZONE]
end

-- A23-90: where the player stands now (the zone loop's last sample), a PvP zone or a PvP area
function ZoneService.IsPvPZone(player)
	return pvpNow[player] == true
end

function ZoneService.IsTown(player)
	return ZoneService.GetZone(player).Town == true
end

-- CR-H2: is `pos` (the player's root position now) a plausible move since the last zone-loop sample? A suspicious
-- move is logged; false is returned ONLY while Config.AntiCheat.Enforce is true (log-only mode: always true).
function ZoneService.IsPlausible(player, pos)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(pos) ~= "Vector3" then return true end
	local ok, flat, rise, allowFlat, allowRise = checkMove(player, pos)
	if ok then return true end
	logSuspicious(player, "check", flat, rise, allowFlat, allowRise)
	return AC.Enforce ~= true
end

-- CR-H2: call right BEFORE a server-side teleport of the player's character; every move is accepted for `seconds`
-- (default Config.AntiCheat.TeleportGrace = 1, max 30) and the movement track restarts at the new position
function ZoneService.MarkTeleported(player, seconds)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	markTeleported(player, seconds)
end

-- SKL-3 Hop: the movement check accepts `studs` more flat movement for `seconds` (the one hop: the track is kept, no
-- grace, a later teleport is still caught). At most 30 studs for 2 s
function ZoneService.AllowMove(player, studs, seconds)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	studs, seconds = tonumber(studs), tonumber(seconds) or 1
	if not studs or studs ~= studs or studs <= 0 or seconds ~= seconds or seconds <= 0 then return end
	move.extra[player] = { Studs = math.min(studs, 30), Until = os.clock() + math.min(seconds, 2) }
end

-- true while a server teleport / correction grace runs (PlayerService ignores that movement as "walking")
function ZoneService.IsTeleportGrace(player)
	return (move.graceUntil[player] or 0) > os.clock()
end

-- Server-only appearance replacement: keep the old position/time/velocity sample and its existing grace.
-- No new spawn/teleport exemption is granted merely because the character Model changed.
function ZoneService.CaptureMovementTrack(player)
	local good = move.lastGood[player]
	return { LastGood = good and table.clone(good) or nil, GraceUntil = move.graceUntil[player] }
end

function ZoneService.RestoreMovementTrack(player, snapshot, character)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(snapshot) ~= "table" then return end
	if typeof(character) ~= "Instance" or not character:IsA("Model") or player.Character ~= character then return end
	local good = snapshot.LastGood and table.clone(snapshot.LastGood) or nil
	if good then good.Char = character end
	move.lastGood[player] = good
	move.graceUntil[player] = snapshot.GraceUntil
end

-- zone.Spawn + random XZ offset in [-6, 6] + (0, 4, 0), facing into the zone. Pure: safe to call any time.
-- faceOut = true (the first mission is still open: PlayerService) faces zone.SpawnLook (the way out of a town: the gate at the
-- bridge end, where the Crossroads Forge lies) instead of the zone middle; a zone without SpawnLook keeps the middle.
function ZoneService.GetSpawnCFrame(zoneId, faceOut)
	local zone = Config.Zones[zoneId] or Config.Zones[DEFAULT_ZONE]
	local base = zone.Spawn
	local pos = Vector3.new(
		base.X + Util.Random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER),
		base.Y + SPAWN_LIFT,
		base.Z + Util.Random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER)
	)
	local target = faceOut == true and typeof(zone.SpawnLook) == "Vector3" and zone.SpawnLook or zone.Center
	if typeof(faceOut) == "Vector3" then target = faceOut end -- playtest r1 ③: a spot to face (the side's guide)
	local look = Vector3.new(target.X, pos.Y, target.Z)
	if (look - pos).Magnitude > 1 then
		return CFrame.lookAt(pos, look)
	end
	return CFrame.new(pos)
end

-- "Home" -> Config.HomeZoneId(faction); others must be a zone id in Config.Travel.Destinations
function ZoneService.ResolveDestination(player, destId)
	if type(destId) ~= "string" then return nil end
	if destId == "Home" then
		return Config.HomeZoneId(getFaction(player))
	end
	if validDestinations[destId] then return destId end
	return nil
end

local function finishChannel(player, zoneId, start)
	if player.Parent == nil then return end
	player:SetAttribute("TravelingUntil", 0)
	local zone = Config.Zones[zoneId]
	local canGo = zone ~= nil
		and S.PlayerService.IsReady(player)
		and Util.IsAlive(player)
		and not combatBlocksTravel(player, start) -- PvP zones: swings / releases landed during the channel block it
		and not hasSack(player)
		and not isKaiju(player)
		and getStars(player) < Config.PvP.NoTravelStars
		and getLevel(player) >= zone.MinLevel
	if canGo and teleport(player, zoneId) then
		updateZone(player)
	else
		notify(player, fmt("TravelCancelled"), "bad")
	end
end

-- (ok, reasonText?) — instant = pads; otherwise a ChannelSeconds channel cancelled by damage / combat tag / sack / kaiju / stars
function ZoneService.Travel(player, destId, instant)
	if not Util.IsAlive(player) then return false, nil end
	local zoneId = ZoneService.ResolveDestination(player, destId)
	local zone = zoneId and Config.Zones[zoneId]
	if not zone then return false, nil end
	if getLevel(player) < zone.MinLevel then
		return false, fmt("NeedLevel", zone.MinLevel)
	end
	if isKaiju(player) then
		return false, fmt("TravelBlockedKaiju")
	end
	if hasSack(player) then
		return false, fmt("TravelBlockedSack")
	end
	if getStars(player) >= Config.PvP.NoTravelStars then
		return false, fmt("TravelBlockedStars")
	end
	if combatBlocksTravel(player, math.huge) then
		return false, fmt("TravelBlockedCombat")
	end
	if channels[player] or (tonumber(player:GetAttribute("TravelingUntil")) or 0) > Util.Now() then
		return false, nil
	end

	if instant then
		if not teleport(player, zoneId) then return false, nil end
		updateZone(player)
		return true, nil
	end

	local start = os.clock()
	local token = {}
	channels[player] = { Token = token, Start = start } -- CR-L18
	player:SetAttribute("TravelingUntil", Util.Now() + Config.Travel.ChannelSeconds) -- the HUD travel bar (no toast, A23-130)
	task.delay(Config.Travel.ChannelSeconds, function()
		local ch = channels[player]
		if not ch or ch.Token ~= token then return end -- cancelled by the zone loop, or the player left
		channels[player] = nil
		local ok, err = pcall(finishChannel, player, zoneId, start)
		if not ok then
			warnThrottled("channel", "travel channel error: " .. tostring(err))
			if player.Parent then player:SetAttribute("TravelingUntil", 0) end
		end
	end)
	return true, nil
end

------------------------------------------------------------------ remote / pads
local function onTravelRemote(player, destId)
	if not S.PlayerService.IsReady(player) then return end
	if type(destId) ~= "string" or #destId > MAX_DEST_LENGTH then return end
	-- A23-182: the menu's teleport is the Fast Travel subscription's (silently nothing without it; the pads stay free)
	local mon = S.MonetizationService
	if not (type(mon) == "table" and type(mon.HasSub) == "function" and mon.HasSub(player, "FastTravel") == true) then return end
	if not Util.RateLimit(player, "Travel", Config.RateLimits.Travel) then return end
	S.PlayerService.MarkActive(player)
	local ok, accepted, reason = pcall(ZoneService.Travel, player, destId, false)
	if not ok then
		warnThrottled("travel", "Travel error: " .. tostring(accepted))
		return
	end
	if not accepted and reason then
		notify(player, reason, "bad")
	end
end

local function playerFromHit(hit)
	local node = hit and hit.Parent
	while node and node ~= workspace do
		if node:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(node)
			if p then return p end
		end
		node = node.Parent
	end
	return nil
end

local function onPadTouched(pad, hit)
	local dest = pad:GetAttribute("TravelTo")
	if type(dest) ~= "string" then return end
	local player = playerFromHit(hit)
	if not player or not S.PlayerService.IsReady(player) then return end
	-- CR-H2 (always enforced): the root must really stand on the pad (no remote firetouchinterest escape)
	local root = Util.GetRoot(player)
	if not root or not pad:IsA("BasePart")
		or Util.FlatDistance(root.Position, pad.Position) > math.max(pad.Size.X, pad.Size.Z) / 2 + acNum("PadSlack", 4) then
		return
	end
	-- CR-H2: a hop onto the pad is checked before Travel's teleport clears the track (logged; refused only with Enforce)
	if not ZoneService.IsPlausible(player, root.Position) then return end
	local now = os.clock()
	local last = lastPadTouch[player]
	if last and now - last < Config.Travel.PadDebounce then return end
	lastPadTouch[player] = now
	local ok, accepted, reason = pcall(ZoneService.Travel, player, dest, true)
	if not ok then
		warnThrottled("pad", "pad travel error: " .. tostring(accepted))
		return
	end
	if not accepted and reason then
		notify(player, reason, "bad")
	end
end

local function hookPad(pad)
	if hookedPads[pad] or not pad:IsA("BasePart") then return end
	if pad:GetAttribute("TravelTo") == nil then return end
	hookedPads[pad] = true
	pad.Touched:Connect(function(hit)
		onPadTouched(pad, hit)
	end)
end

local function hookPadsFolder(map)
	local pads = map and map:FindFirstChild("Pads")
	if not pads then
		Util.Warn(TAG, "workspace.Map.Pads not found; travel pads are inactive")
		return
	end
	for _, child in pads:GetChildren() do
		hookPad(child)
	end
	-- pads added later (e.g. MapBuilder.Build re-creating a missing pad)
	pads.ChildAdded:Connect(function(child)
		task.defer(hookPad, child) -- attributes are set right after parenting
	end)
end

------------------------------------------------------------------ lifecycle
function ZoneService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		zoneIds[player] = DEFAULT_ZONE
		pvpNow[player] = false -- A23-90
		player:SetAttribute("ZoneId", DEFAULT_ZONE)
		player:SetAttribute("ZonePvP", false)
		player:SetAttribute("ZoneTown", true)
		player:SetAttribute("TravelingUntil", 0)
	end)
	S.PlayerService.CharacterSpawned:Connect(function(player, _character, _humanoid, cosmetic)
		if cosmetic then return end -- the ordinary zone tick continues the preserved movement track
		markTeleported(player, acNum("SpawnGrace", 2)) -- CR-H2: spawn pivot of a new character
		updateZone(player)
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		-- deferred: other PlayerLeaving handlers may still read the cached zone
		task.defer(cleanup, player)
	end)
end

function ZoneService.Start()
	Net.Get("Travel").OnServerEvent:Connect(onTravelRemote)

	hookPadsFolder(workspace:FindFirstChild("Map"))
	-- MapBuilder.Rebuild() replaces workspace.Map: hook the new pads too
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Map" then
			task.defer(hookPadsFolder, child)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(cleanup, player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Travel.ZoneTick)
			for _, player in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(updateZone, player)
				if not ok then
					warnThrottled("loop", "zone loop error: " .. tostring(err))
				end
			end
		end
	end)

	print("[ZoneService] started")
end

return ZoneService
