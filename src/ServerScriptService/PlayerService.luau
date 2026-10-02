-- PlayerService.luau : join/leave lifecycle, attribute mirroring, leaderstats, spawn/respawn, MaxHealth/WalkSpeed,
-- playtime, Regular's Luck minutes, the no-player-collision group (addendum A7-5), fall rescue (A10), slope limit
-- (A11-R2), camera zoom limits (A12) and BindToClose.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local TAG = "PlayerService"

local PlayerService = {}

-- public signals (top level so they exist before any Init)
PlayerService.PlayerReady = Util.Signal.new() -- (player, data)
PlayerService.PlayerLeaving = Util.Signal.new() -- (player, data) fired once, BEFORE the final save
PlayerService.CharacterSpawned = Util.Signal.new() -- (player, character, humanoid)
PlayerService.CharacterDied = Util.Signal.new() -- (player, character)

local S = nil

local ready = {} -- [Player] = true
local joining = {} -- [Player] = true while the data load runs
local finalizing = {} -- [Player] = true while FinalizeLeave runs
local removed = setmetatable({}, { __mode = "k" }) -- [Player] = true once PlayerRemoving fired
local conns = {} -- [Player] = { RBXScriptConnection }
local lastActive = {} -- [Player] = os.clock() of the last input/combat
local regularMinutes = {} -- [Player] = active minutes on this server
local mirrored = {} -- [key] = true for every key of Config.Data.Mirrored
local closing = false

local COLLISION_GROUP = Config.Player.CollisionGroup or "Players"
local collisionGroupOk = false

local CHILD_TIMEOUT = 5 -- seconds to wait for Humanoid / HumanoidRootPart / parenting
local CLOSE_TIMEOUT = 25 -- BindToClose budget
local FINALIZE_WAIT = 30 -- a second FinalizeLeave call waits this long for the first one
local LEADERSTAT_KEYS = { "Level", "BankGold", "CarriedGold", "Rebirths", "Honor", "Infamy", "Faction" }

-- A10: a player below this Y (anywhere: sea, river bed, out of the world) is put back on their home spawn.
-- Swimming stays enabled on player Humanoids (the water surface is at Y = -1.2).
local FALL_RESCUE_Y = -20
local FALL_CHECK_INTERVAL = Config.Travel.ZoneTick or 0.5
local MAX_SLOPE_ANGLE = 46 -- A11-R2: Terrain ridges (>= 50 deg) cannot be walked over
local CAMERA_MAX_ZOOM = 40 -- A12: players never see the whole world (kaiju may raise it while transformed)
local CAMERA_MIN_ZOOM = 6
------------------------------------------------------------------ helpers
local lastLoopWarn = {}
local function loopWarn(loopName, err)
	local now = os.clock()
	if now - (lastLoopWarn[loopName] or -math.huge) >= 10 then
		lastLoopWarn[loopName] = now
		Util.Warn(TAG, loopName .. ": " .. tostring(err))
	end
end

local function addConn(player, conn)
	local list = conns[player]
	if not list then
		list = {}
		conns[player] = list
	end
	table.insert(list, conn)
end

-- persisted value (data table first, attribute as fallback)
local function stat(player, key, default)
	local data = S.DataService.Get(player)
	local v = data and data[key]
	if v == nil then v = player:GetAttribute(key) end
	if v == nil then return default end
	return v
end

local function classDef(player)
	local cs = S.ClassService
	if cs and cs.GetClassDef then
		local ok, def = pcall(cs.GetClassDef, player)
		if ok and type(def) == "table" then return def end
	end
	return Config.Classes[stat(player, "Class", "Warrior")] or Config.Classes.Warrior
end

local function healthMult(player)
	local js = S.JusticeService
	if js and js.GetHealthMult then
		local ok, m = pcall(js.GetHealthMult, player)
		if ok and type(m) == "number" and m == m and m > 0 and m < math.huge then return m end
	end
	return 1
end

local function computeMaxHealth(player)
	local level = tonumber(stat(player, "Level", 1)) or 1
	local faction = stat(player, "Faction", "None")
	local class = stat(player, "Class", "Warrior")
	return math.max(1, math.floor(Config.MaxHealth(level, faction, class) * healthMult(player)))
end

-- health/speed formula on a given humanoid (used on spawn and by RefreshCharacter)
local function applyStats(player, humanoid, fullHeal)
	local maxHP = computeMaxHealth(player)
	if humanoid.Health <= 0 then
		humanoid.MaxHealth = maxHP -- never revive
		return
	end
	local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	humanoid.MaxHealth = maxHP
	if fullHeal then
		humanoid.Health = maxHP
	else
		humanoid.Health = math.clamp(ratio * maxHP, 1, maxHP)
	end
	humanoid.WalkSpeed = Config.Player.WalkSpeed * (classDef(player).WalkSpeedMult or 1)
end

local function spawnCFrame(zoneId)
	local zs = S.ZoneService
	if zs and zs.GetSpawnCFrame then
		local ok, cf = pcall(zs.GetSpawnCFrame, zoneId)
		if ok and typeof(cf) == "CFrame" then return cf end
		if not ok then Util.Warn(TAG, "GetSpawnCFrame failed: " .. tostring(cf)) end
	end
	local z = Config.Zones[zoneId] or Config.Zones.Crossroads
	return CFrame.new(z.Spawn + Vector3.new(0, 4, 0))
end

local function loadCharacter(player)
	if player.Parent == nil then return end
	local ok, err = pcall(player.LoadCharacter, player)
	if not ok then
		Util.Warn(TAG, "LoadCharacter failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- A12: on join and on every CharacterAdded (max first, so min never exceeds max)
local function applyCameraLimits(player)
	local ok, err = pcall(function()
		player.CameraMaxZoomDistance = CAMERA_MAX_ZOOM
		player.CameraMinZoomDistance = CAMERA_MIN_ZOOM
	end)
	if not ok then
		loopWarn("camera limits", err)
	end
end

-- A10: below FALL_RESCUE_Y -> home spawn (the sack / kaiju state is untouched, like the enemy-town bounce)
local function rescueIfFallen(player)
	local character = Util.GetCharacter(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or root.Position.Y >= FALL_RESCUE_Y then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	character:PivotTo(spawnCFrame(Config.HomeZoneId(stat(player, "Faction", "None"))))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

------------------------------------------------------------------ collision group (A7-5)
local function setupCollisionGroup()
	local ok, err = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
		end
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
	end)
	collisionGroupOk = ok
	if not ok then
		Util.Warn(TAG, "collision group setup failed: " .. tostring(err))
	end
end

local function setPartGroup(inst)
	if inst:IsA("BasePart") then
		inst.CollisionGroup = COLLISION_GROUP
	end
end

local function assignCollisionGroup(character)
	if not collisionGroupOk then return end
	for _, d in character:GetDescendants() do
		setPartGroup(d)
	end
	-- the connection dies with the character
	character.DescendantAdded:Connect(setPartGroup)
end

------------------------------------------------------------------ leaderstats
local function toInt(v)
	v = tonumber(v) or 0
	if v ~= v or v == math.huge or v == -math.huge then return 0 end
	return math.floor(v)
end

local function buildLeaderstats(player)
	local old = player:FindFirstChild("leaderstats")
	if old then old:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local function intValue(name)
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = folder
		return v
	end
	-- creation order = column order in the player list
	local levelV = intValue("레벨")
	local goldV = intValue("골드")
	local rebirthV = intValue("환생")
	local fameV = intValue("명성")

	local function update()
		levelV.Value = toInt(player:GetAttribute("Level"))
		goldV.Value = toInt(player:GetAttribute("BankGold")) + toInt(player:GetAttribute("CarriedGold"))
		rebirthV.Value = toInt(player:GetAttribute("Rebirths"))
		local f = player:GetAttribute("Faction")
		if f == "Halo" then
			fameV.Value = toInt(player:GetAttribute("Honor"))
		elseif f == "Horns" then
			fameV.Value = toInt(player:GetAttribute("Infamy"))
		else
			fameV.Value = 0 -- None / Neutral (phase 2 adds 장인 명성)
		end
	end
	update()
	folder.Parent = player

	for _, key in LEADERSTAT_KEYS do
		addConn(player, player:GetAttributeChangedSignal(key):Connect(update))
	end
end

------------------------------------------------------------------ character lifecycle
local function onCharacterAdded(player, character)
	assignCollisionGroup(character)

	local humanoid = character:WaitForChild("Humanoid", CHILD_TIMEOUT)
	local root = character:WaitForChild("HumanoidRootPart", CHILD_TIMEOUT)
	if not humanoid or not root or not humanoid:IsA("Humanoid") then
		if player.Character == character then
			Util.Warn(TAG, "character of " .. player.Name .. " has no Humanoid/HumanoidRootPart; skipped")
		end
		return
	end
	humanoid.MaxSlopeAngle = MAX_SLOPE_ANGLE -- A11-R2 (Swimming stays enabled for players, A10)
	if player.Character ~= character or not ready[player] then return end
	applyCameraLimits(player)

	-- CharacterAdded can fire before the model is parented: wait until it is in the world before placing it
	local t0 = os.clock()
	while character.Parent == nil and os.clock() - t0 < CHILD_TIMEOUT do
		task.wait()
	end
	if player.Character ~= character or character.Parent == nil or not ready[player] then return end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	applyStats(player, humanoid, true)
	character:PivotTo(spawnCFrame(Config.HomeZoneId(stat(player, "Faction", "None"))))

	humanoid.Died:Once(function()
		-- a character already replaced by LoadCharacter (Respawn) is not a death
		if not ready[player] or player.Parent == nil or player.Character ~= character then return end
		PlayerService.CharacterDied:Fire(player, character)
		task.delay(Config.Player.RespawnTime, function()
			if player.Parent and player.Character == character and ready[player] then
				loadCharacter(player)
			end
		end)
	end)

	PlayerService.CharacterSpawned:Fire(player, character, humanoid)
end

------------------------------------------------------------------ join
local function onJoin(player)
	if ready[player] or joining[player] or finalizing[player] then return end
	applyCameraLimits(player) -- A12: before the first character
	joining[player] = true
	local ok, data = pcall(S.DataService.Load, player)
	joining[player] = nil
	if not ok then
		Util.Warn(TAG, "load error for " .. player.Name .. ": " .. tostring(data))
		data = nil
	end
	if player.Parent == nil then return end

	-- left (or the server started closing) while the load was finishing: hand the data straight back
	if data ~= nil and (removed[player] or closing) then
		pcall(S.DataService.Release, player)
		return
	end
	if data == nil then
		player:Kick(string.format(Config.Text.LoadFailed))
		return
	end

	for _, key in Config.Data.Mirrored do
		local v = data[key]
		if v ~= nil and type(v) ~= "table" then
			player:SetAttribute(key, v)
		end
	end
	regularMinutes[player] = 0
	player:SetAttribute("RegularMinutes", 0)
	buildLeaderstats(player)

	-- connected before PlayerReady so a Respawn() from a PlayerReady handler is never missed
	addConn(player, player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end))

	ready[player] = true
	player:SetAttribute("DataLoaded", true)
	PlayerService.PlayerReady:Fire(player, data)

	if ready[player] then
		loadCharacter(player)
	end
end

------------------------------------------------------------------ shutdown
local function onClose()
	closing = true
	local targets = {}
	for _, p in Players:GetPlayers() do
		targets[p] = true
	end
	for p in ready do
		targets[p] = true
	end

	local pending = 0
	for p in targets do
		pending += 1
		task.spawn(function()
			local ok, err = pcall(PlayerService.FinalizeLeave, p)
			if not ok then Util.Warn(TAG, "FinalizeLeave on close failed: " .. tostring(err)) end
			pending -= 1
		end)
	end

	local t0 = os.clock()
	while (pending > 0 or next(finalizing) ~= nil or next(joining) ~= nil) and os.clock() - t0 < CLOSE_TIMEOUT do
		task.wait(0.1)
	end
end

------------------------------------------------------------------ public API
function PlayerService.Init(registry)
	S = registry
	Players.CharacterAutoLoads = false
	for _, key in Config.Data.Mirrored do
		mirrored[key] = true
	end
	setupCollisionGroup()
end

function PlayerService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onJoin, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		removed[player] = true
		PlayerService.FinalizeLeave(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end

	game:BindToClose(onClose)

	-- playtime
	task.spawn(function()
		local step = Config.Player.PlaytimeTick
		while true do
			task.wait(step)
			for _, p in PlayerService.GetReadyPlayers() do
				local ok, err = pcall(PlayerService.AddStat, p, "PlaytimeSeconds", step)
				if not ok then loopWarn("playtime loop", err) end
			end
		end
	end)

	-- A10 fall rescue (sea / out of the world)
	task.spawn(function()
		while true do
			task.wait(FALL_CHECK_INTERVAL)
			for _, p in PlayerService.GetReadyPlayers() do
				local ok, err = pcall(rescueIfFallen, p)
				if not ok then loopWarn("fall rescue loop", err) end
			end
		end
	end)

	-- Regular's Luck: one minute counts if the player had input/combat within it
	task.spawn(function()
		local period = Config.Luck.MinuteSeconds
		while true do
			task.wait(period)
			local now = os.clock()
			for _, p in PlayerService.GetReadyPlayers() do
				local ok, err = pcall(function()
					local t = lastActive[p]
					if t and now - t <= period then
						local n = (regularMinutes[p] or 0) + 1
						regularMinutes[p] = n
						p:SetAttribute("RegularMinutes", n)
					end
				end)
				if not ok then loopWarn("regular-minutes loop", err) end
			end
		end
	end)

	print("[PlayerService] started")
end

function PlayerService.IsReady(player)
	return player ~= nil and ready[player] == true
end

function PlayerService.GetReadyPlayers()
	local out = {}
	for _, p in Players:GetPlayers() do
		if ready[p] then
			table.insert(out, p)
		end
	end
	return out
end

function PlayerService.GetData(player)
	return S.DataService.Get(player)
end

function PlayerService.SetStat(player, key, value)
	local data = S.DataService.Get(player)
	if not data then return end
	data[key] = value
	if mirrored[key] then
		player:SetAttribute(key, value)
	end
end

function PlayerService.AddStat(player, key, delta)
	local data = S.DataService.Get(player)
	if not data then return 0 end
	local newValue = (tonumber(data[key]) or 0) + (tonumber(delta) or 0)
	PlayerService.SetStat(player, key, newValue)
	return newValue
end

function PlayerService.Respawn(player)
	if not ready[player] or player.Parent == nil then return end
	task.spawn(loadCharacter, player)
end

-- recompute MaxHealth + WalkSpeed of the current character (keeps the HP ratio unless fullHeal)
function PlayerService.RefreshCharacter(player, fullHeal)
	local humanoid = Util.GetHumanoid(player)
	if not humanoid then return end
	applyStats(player, humanoid, fullHeal == true)
end

-- idempotent: PlayerLeaving + final save once; always clears per-player state
function PlayerService.FinalizeLeave(player)
	if finalizing[player] then
		local t0 = os.clock()
		while finalizing[player] and os.clock() - t0 < FINALIZE_WAIT do
			task.wait(0.1)
		end
		return
	end

	if ready[player] then
		finalizing[player] = true
		PlayerService.PlayerLeaving:Fire(player, S.DataService.Get(player))
		ready[player] = nil -- loops and remotes stop touching the player while the final save runs
		local ok, err = pcall(S.DataService.Release, player)
		if not ok then
			Util.Warn(TAG, "release failed for " .. player.Name .. ": " .. tostring(err))
		end
		finalizing[player] = nil
	end

	ready[player] = nil
	Util.ClearPlayer(player)
	lastActive[player] = nil
	regularMinutes[player] = nil
	local list = conns[player]
	conns[player] = nil
	if list then
		for _, c in list do
			c:Disconnect()
		end
	end
end

function PlayerService.MarkActive(player)
	if ready[player] then
		lastActive[player] = os.clock()
	end
end

function PlayerService.GetRegularMinutes(player)
	return regularMinutes[player] or 0
end

return PlayerService
