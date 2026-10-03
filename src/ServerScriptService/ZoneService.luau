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
local ENEMY_TOWN_FALLBACK = "상대 진영 마을에는 들어갈 수 없어요!" -- used only if Config.Text.EnemyTown is missing
local KAIJU_TOWN_FALLBACK = "괴수는 마을에 들어갈 수 없어요!" -- TODO(config): Config.Text.KaijuNoTown (used if present)

local S = nil
local zoneIds = {} -- [Player] = cached zone id
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

local function notify(player, text, kind)
	if type(text) == "string" and text ~= "" then
		Net.Notify(player, text, kind)
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

-- pivots the character to a zone spawn; false when there is no character / root
local function teleport(player, zoneId)
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
		or lastDamagedAt(player) >= ch.Start
		or inCombat(player)
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
		notify(player, fmt("TravelCancelled"), "bad")
	end
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
	if root.Position.Y < RESCUE_Y then
		if not validateRescue(player, root) then return end -- CR-H2 (pulled back only with AntiCheat.Enforce)
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

	local old = zoneIds[player] or DEFAULT_ZONE
	if zone.Id == old then return end
	zoneIds[player] = zone.Id
	player:SetAttribute("ZoneId", zone.Id)
	player:SetAttribute("ZonePvP", zone.PvP == true)
	player:SetAttribute("ZoneTown", zone.Town == true)

	local oldZone = Config.Zones[old]
	local wasPvP = oldZone ~= nil and oldZone.PvP == true
	if zone.PvP and not wasPvP then
		if getFaction(player) == "Neutral" then
			notify(player, fmt("EnteredPvPNeutral"), "info") -- CR-L24: 장인 길드 is immune to PvP
		else
			notify(player, fmt("EnteredPvP"), "bad")
		end
	elseif not zone.PvP and wasPvP then
		notify(player, fmt("EnteredSafe"), "good")
	end
	ZoneService.ZoneChanged:Fire(player, zone.Id, old)
end

local function cleanup(player)
	zoneIds[player] = nil
	lastGateNotify[player] = nil
	lastPadTouch[player] = nil
	channels[player] = nil -- CR-L18
	move.lastGood[player] = nil -- CR-H2
	move.graceUntil[player] = nil
	move.lastLog[player] = nil
end

------------------------------------------------------------------ public API
function ZoneService.GetZoneId(player)
	return zoneIds[player] or DEFAULT_ZONE
end

function ZoneService.GetZone(player)
	return Config.Zones[ZoneService.GetZoneId(player)] or Config.Zones[DEFAULT_ZONE]
end

function ZoneService.IsPvPZone(player)
	return ZoneService.GetZone(player).PvP == true
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
function ZoneService.GetSpawnCFrame(zoneId)
	local zone = Config.Zones[zoneId] or Config.Zones[DEFAULT_ZONE]
	local base = zone.Spawn
	local pos = Vector3.new(
		base.X + Util.Random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER),
		base.Y + SPAWN_LIFT,
		base.Z + Util.Random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER)
	)
	local look = Vector3.new(zone.Center.X, pos.Y, zone.Center.Z)
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
		and lastDamagedAt(player) < start
		and not inCombat(player) -- swings / releases landed during the channel tag the attacker (no escape by Travel)
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
	if inCombat(player) then
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
	player:SetAttribute("TravelingUntil", Util.Now() + Config.Travel.ChannelSeconds)
	notify(player, fmt("Traveling"), "info")
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
