-- ZoneService.luau : zone tracking, level gates, enemy-town bounce, Travel remote, teleport pads, spawn CFrames.
--
-- Zones are XZ rectangles from Config (Config.ZoneAt); the current zone of every ready player is cached here and
-- mirrored to the attributes ZoneId / ZonePvP / ZoneTown. Addendum A3-L1 + A6: a Halo/Horns/Neutral player standing in a
-- faction town that is not theirs (Neutral: either faction town) is bounced to the Crossroads spawn
-- (kaiju and sack carriers too; the sack keeps its state). "None" (no faction chosen yet) is not bounced.
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
local ENEMY_TOWN_FALLBACK = "상대 진영 마을에는 들어갈 수 없어요!" -- used only if Config.Text.EnemyTown is missing

local S = nil
local zoneIds = {} -- [Player] = cached zone id
local lastGateNotify = {} -- [Player] = os.clock() of the last bounce toast
local lastPadTouch = {} -- [Player] = os.clock() of the last handled pad touch
local hookedPads = setmetatable({}, { __mode = "k" }) -- [BasePart] = true
local lastWarnAt = {}

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

-- pivots the character to a zone spawn; false when there is no character / root
local function teleport(player, zoneId)
	local character = Util.GetCharacter(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
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

-- A3-L1 / A6: a faction town that is not the player's own. "None" (no side chosen yet) is never bounced.
local function isForbiddenTown(player, zone)
	if not zone.Town or zone.Faction == nil then return false end
	local f = getFaction(player)
	if f == "None" then return false end
	return f ~= zone.Faction
end

-- the zone-loop body (also run on CharacterSpawned and right after a teleport)
local function updateZone(player)
	if not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return end
	local root = Util.GetRoot(player)
	if not root then return end
	local zone = Config.ZoneAt(root.Position)

	if getLevel(player) < zone.MinLevel then
		teleport(player, DEFAULT_ZONE)
		notifyBounce(player, fmt("NeedLevel", zone.MinLevel))
		return
	end
	if isForbiddenTown(player, zone) then
		teleport(player, DEFAULT_ZONE)
		notifyBounce(player, fmt("EnemyTown") or ENEMY_TOWN_FALLBACK)
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
		notify(player, fmt("EnteredPvP"), "bad")
	elseif not zone.PvP and wasPvP then
		notify(player, fmt("EnteredSafe"), "good")
	end
	ZoneService.ZoneChanged:Fire(player, zone.Id, old)
end

local function cleanup(player)
	zoneIds[player] = nil
	lastGateNotify[player] = nil
	lastPadTouch[player] = nil
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

-- (ok, reasonText?) — instant = pads; otherwise a ChannelSeconds channel cancelled by damage / sack / kaiju / stars
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
	if (tonumber(player:GetAttribute("TravelingUntil")) or 0) > Util.Now() then
		return false, nil
	end

	if instant then
		if not teleport(player, zoneId) then return false, nil end
		updateZone(player)
		return true, nil
	end

	player:SetAttribute("TravelingUntil", Util.Now() + Config.Travel.ChannelSeconds)
	notify(player, fmt("Traveling"), "info")
	local start = os.clock()
	task.delay(Config.Travel.ChannelSeconds, function()
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
	S.PlayerService.CharacterSpawned:Connect(function(player)
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
