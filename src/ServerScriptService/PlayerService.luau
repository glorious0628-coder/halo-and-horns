-- PlayerService.luau : join/leave lifecycle, attribute mirroring, leaderstats, spawn/respawn, MaxHealth/WalkSpeed,
-- playtime, Regular's Luck minutes, the no-player-collision group (addendum A7-5), slope limit (A11-R2), camera zoom
-- limits (A12), anti-collusion pair cooldowns (CR-M4) and BindToClose. Fall rescue (A10) is owned by ZoneService.
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
PlayerService.CharacterSpawned = Util.Signal.new() -- (player, character, humanoid, cosmetic: boolean?)
PlayerService.CharacterDied = Util.Signal.new() -- (player, character)

local S = nil

local ready = {} -- [Player] = true
local joining = {} -- [Player] = true while the data load runs
local finalizing = {} -- [Player] = true while FinalizeLeave runs
-- CR-M2: [Player] = true once onClose fired PlayerLeaving (ready kept); "saving" while that player's release runs
local leftFired = {}
local removed = setmetatable({}, { __mode = "k" }) -- [Player] = true once PlayerRemoving fired
local conns = {} -- [Player] = { RBXScriptConnection }
local lastActive = {} -- [Player] = os.clock() of the last input/combat
local regularMinutes = {} -- [Player] = active minutes on this server
local mirrored = {} -- [key] = true for every key of Config.Data.Mirrored
local characterLoading = {} -- [Player] = true while a normal spawn is being installed
local respawnQueued = {} -- [Player] = one additional requested respawn while the current load yields
local cosmeticContext = setmetatable({}, { __mode = "k" }) -- [Model] = server-only snapshot for an appearance replacement
local closing = false

local COLLISION_GROUP = Config.Player.CollisionGroup or "Players"
local collisionGroupOk = false

local CHILD_TIMEOUT = 5 -- seconds to wait for Humanoid / HumanoidRootPart / parenting
local CLOSE_TIMEOUT = 25 -- BindToClose budget
local FINALIZE_WAIT = 30 -- a second FinalizeLeave call waits this long for the first one
local LEADERSTAT_KEYS = { "Level", "BankGold", "CarriedGold", "Rebirths", "Honor", "Infamy", "Faction" }

local MAX_SLOPE_ANGLE = 46 -- A11-R2: Terrain ridges (>= 50 deg) cannot be walked over
local CAMERA_MAX_ZOOM = 40 -- A12: players never see the whole world (kaiju may raise it while transformed)
local CAMERA_MIN_ZOOM = 6
-- CR-M4: PairCD entries older than this are dropped at PlayerReady (>= every pair cooldown / window that uses them)
local PAIR = {
	MinKeep = 1800,
	MaxKeys = 200,
	-- { Config table, key } read for the keep window (a longer configured cooldown keeps its entries longer)
	KeepFrom = {
		{ "Kaiju", "PairRewardCooldown" }, { "PvP", "PairRewardCooldown" }, { "Bully", "RepeatWindow" },
		{ "Grudge", "RefundBonusCooldown" }, { "Grudge", "RestealWindow" },
	},
}
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

-- CR-H2: tell ZoneService's movement check that the server is about to move this player (no false "teleport" log)
local function markTeleported(player, seconds)
	local zs = S.ZoneService
	if zs and zs.MarkTeleported then
		local ok, err = pcall(zs.MarkTeleported, player, seconds)
		if not ok then loopWarn("MarkTeleported", err) end
	end
end

local function loadCharacter(player)
	if player.Parent == nil or not ready[player] then return end
	if characterLoading[player] then
		respawnQueued[player] = true
		return
	end
	characterLoading[player] = true
	-- CR-H2: the new character appears at a spawn point first; onCharacterAdded marks again before placing it
	markTeleported(player, (Config.AntiCheat and Config.AntiCheat.SpawnGrace) or 2)
	local ok, err = pcall(function()
		local costumes = S.CostumeService
		local custom = costumes and costumes.CreateSpawnCharacter(player)
		if custom and PlayerService.SpawnCharacter(player, custom) then return end
		if custom then custom:Destroy() end
		player:LoadCharacter()
	end)
	characterLoading[player] = nil
	if not ok then
		Util.Warn(TAG, "LoadCharacter failed for " .. player.Name .. ": " .. tostring(err))
	end
	if respawnQueued[player] then
		respawnQueued[player] = nil
		if ready[player] and player.Parent then task.defer(loadCharacter, player) end
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

------------------------------------------------------------------ pair cooldowns (CR-M4)
local function pairKeepSeconds()
	local keep = PAIR.MinKeep
	for _, ref in PAIR.KeepFrom do
		local t = Config[ref[1]]
		local v = type(t) == "table" and tonumber(t[ref[2]]) or nil
		if v and v == v and v > keep and v < math.huge then keep = v end
	end
	local b = Config.Bully
	if type(b) == "table" then -- PvPService's bully bounty window (DecaySeconds * MaxStacks)
		local v = (tonumber(b.DecaySeconds) or 0) * (tonumber(b.MaxStacks) or 0)
		if v == v and v > keep and v < math.huge then keep = v end
	end
	return keep
end

-- os.time() of an entry: a number, or the newest of a { t1, t2 } list ("kolog:<victimUserId>")
local function pairStamp(v)
	if type(v) == "table" then
		local newest = nil
		for _, item in v do
			local t = tonumber(item)
			if t and t == t and (newest == nil or t > newest) then newest = t end
		end
		return newest
	end
	local t = tonumber(v)
	if t and t == t then return t end
	return nil
end

-- drops entries older than the keep window (or far in the future: bad clock), then the oldest above MaxKeys
local function prunePairCD(data)
	if type(data) ~= "table" then return end
	if type(data.PairCD) ~= "table" then
		data.PairCD = {}
		return
	end
	local cd = data.PairCD
	local now = os.time()
	local keep = pairKeepSeconds()
	local list = {}
	for k, v in cd do
		local t = pairStamp(v)
		if type(k) ~= "string" or t == nil or now - t > keep or t - now > keep then
			cd[k] = nil
		else
			table.insert(list, { K = k, T = t })
		end
	end
	if #list > PAIR.MaxKeys then
		table.sort(list, function(a, b) return a.T < b.T end)
		for i = 1, #list - PAIR.MaxKeys do
			cd[list[i].K] = nil
		end
	end
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
-- Humanoid.HipHeight uses different standing-height formulas for R15 and R6.
local function standingHeight(character, humanoid, root)
	if not character or not humanoid or not root or not root:IsA("BasePart") then return nil end
	local height = humanoid.HipHeight + root.Size.Y * 0.5
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg")
		if not leg or not leg:IsA("BasePart") then return nil end
		height += leg.Size.Y
	end
	return height == height and height > 0 and height < math.huge and height or nil
end

local function cosmeticPivot(character, humanoid, root, context)
	local pivot = context.OriginalPivot or context.Pivot
	local height = standingHeight(character, humanoid, root)
	if height and context.StandingHeight then
		-- World Y only: preserve the feet's height, XZ, facing and airborne offset.
		pivot += Vector3.new(0, height - context.StandingHeight, 0)
	end
	context.Pivot = pivot -- recompute from OriginalPivot after spawn handlers scale the new rig
	return pivot
end

local function onCharacterAdded(player, character)
	local context = cosmeticContext[character]
	cosmeticContext[character] = nil
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
	if context then humanoid.Health = math.min(context.Health, humanoid.MaxHealth) end
	if not context then markTeleported(player, (Config.AntiCheat and Config.AntiCheat.SpawnGrace) or 2) end -- CR-H2
	character:PivotTo(context and cosmeticPivot(character, humanoid, root, context)
		or spawnCFrame(Config.HomeZoneId(stat(player, "Faction", "None"))))

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

	PlayerService.CharacterSpawned:Fire(player, character, humanoid, context ~= nil)
	if context and player.Character == character and character.Parent and humanoid.Health > 0 then
		-- JusticeService may scale the new rig; recalculate its standing height without accumulating an offset.
		character:PivotTo(cosmeticPivot(character, humanoid, root, context))
		root.AssemblyLinearVelocity = context.LinearVelocity
		root.AssemblyAngularVelocity = context.AngularVelocity
	end
	if context and context.MovementTrack and S.ZoneService and S.ZoneService.RestoreMovementTrack then
		-- Spawn handlers (including JusticeService scale/lift) are synchronous and may mark a teleport.
		-- Restore after all of them: a cosmetic switch neither resets the position sample nor renews grace.
		S.ZoneService.RestoreMovementTrack(player, context.MovementTrack, character)
	end
end

------------------------------------------------------------------ join
local function onJoin(player)
	if ready[player] or joining[player] or finalizing[player] then return end
	applyCameraLimits(player) -- A12: before the first character
	joining[player] = true
	local ok, data = pcall(S.DataService.Load, player)
	if not ok then
		Util.Warn(TAG, "load error for " .. player.Name .. ": " .. tostring(data))
		data = nil
	end

	-- left (or the server started closing) while the load was finishing: hand the data straight back.
	-- CR-L2: joining stays set until the release finished, so onClose waits for this save too
	if data ~= nil and (player.Parent == nil or removed[player] or closing) then
		local okRel, errRel = pcall(S.DataService.Release, player)
		if not okRel then Util.Warn(TAG, "release failed for " .. player.Name .. ": " .. tostring(errRel)) end
		joining[player] = nil
		return
	end
	joining[player] = nil
	if player.Parent == nil then return end
	if data == nil then
		player:Kick(string.format(Config.Text.LoadFailed))
		return
	end

	local okPrune, errPrune = pcall(prunePairCD, data) -- CR-M4
	if not okPrune then Util.Warn(TAG, "PairCD prune failed for " .. player.Name .. ": " .. tostring(errPrune)) end

	for _, key in Config.Data.Mirrored do
		local v = data[key]
		if v ~= nil and type(v) ~= "table" then
			player:SetAttribute(key, v)
		end
	end
	regularMinutes[player] = 0
	-- A saved nickname is untrusted until the global reservation and current text filter are verified.
	player:SetAttribute("Nickname", "")
	player:SetAttribute("NicknameVerified", false)
	player:SetAttribute("NicknameStatus", "Loading")
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

	-- CR-M2: fire PlayerLeaving for every ready player BEFORE any of them is released, keeping ready set, so
	-- cross-player handlers (e.g. a thief's sack refund to a victim) still land in the other player's data.
	-- FinalizeLeave then only runs the final save (leftFired branch).
	local pre = {}
	for p in ready do
		table.insert(pre, p)
	end
	for _, p in pre do
		if ready[p] and not finalizing[p] and not leftFired[p] then
			finalizing[p] = true -- a concurrent FinalizeLeave (PlayerRemoving) waits while the handlers run
			local okFire, errFire = pcall(function()
				PlayerService.PlayerLeaving:Fire(p, S.DataService.Get(p))
			end)
			if not okFire then Util.Warn(TAG, "PlayerLeaving on close failed: " .. tostring(errFire)) end
			leftFired[p] = true
		end
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

function PlayerService.IsSpawning(player)
	return characterLoading[player] == true
end

-- Server-owned character installation. Appearance swaps do not fire CharacterDied or grant a new spawn shield.
local function installCharacter(player, character, context, expectedOld)
	if not ready[player] or player.Parent ~= Players or player.Character ~= expectedOld then return false end
	if typeof(character) ~= "Instance" or not character:IsA("Model") or character.Parent ~= nil then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return false end
	local ok, err = pcall(function()
		character.Name = player.Name
		character.PrimaryPart = root
		if context then
			context.OriginalPivot = context.Pivot
			for _, child in character:GetChildren() do
				if child:IsA("ForceField") then child:Destroy() end
			end
			character:PivotTo(cosmeticPivot(character, humanoid, root, context))
			cosmeticContext[character] = context
		end
		character.Parent = workspace
		-- The context is registered before CharacterAdded fires, for both immediate and deferred signal modes.
		player.Character = character
	end)
	if not ok then
		cosmeticContext[character] = nil
		pcall(character.Destroy, character)
		Util.Warn(TAG, "character installation failed: " .. tostring(err))
		return false
	end
	if expectedOld and expectedOld ~= character then
		-- Move existing shields rather than cloning them: their original expiration callbacks still apply.
		if context then
			for _, child in expectedOld:GetChildren() do
				if child:IsA("ForceField") then child.Parent = character end
			end
		end
		pcall(expectedOld.Destroy, expectedOld)
	end
	pcall(root.SetNetworkOwner, root, player)
	return true
end

function PlayerService.SpawnCharacter(player, character)
	return installCharacter(player, character, nil, player.Character)
end

function PlayerService.ReplaceCharacter(player, character, expectedOld)
	local old = player.Character
	if old ~= expectedOld or characterLoading[player] or not Util.IsAlive(player) then return false end
	local humanoid = Util.GetHumanoid(player)
	local root = Util.GetRoot(player)
	local context = {
		Health = humanoid.Health,
		Pivot = old:GetPivot(),
		StandingHeight = standingHeight(old, humanoid, root),
		LinearVelocity = root.AssemblyLinearVelocity,
		AngularVelocity = root.AssemblyAngularVelocity,
	}
	if S.ZoneService and S.ZoneService.CaptureMovementTrack then
		context.MovementTrack = S.ZoneService.CaptureMovementTrack(player)
	end
	return installCharacter(player, character, context, old)
end

-- recompute MaxHealth + WalkSpeed of the current character (keeps the HP ratio unless fullHeal)
function PlayerService.RefreshCharacter(player, fullHeal)
	local humanoid = Util.GetHumanoid(player)
	if not humanoid then return end
	applyStats(player, humanoid, fullHeal == true)
end

-- idempotent: PlayerLeaving + final save once; always clears per-player state
function PlayerService.FinalizeLeave(player)
	if leftFired[player] == true then
		-- CR-M2: onClose already fired PlayerLeaving (ready was kept for cross-player refunds): only the save is left
		leftFired[player] = "saving" -- a concurrent call takes the finalizing branch below and waits
		ready[player] = nil
		local ok, err = pcall(S.DataService.Release, player)
		if not ok then
			Util.Warn(TAG, "release failed for " .. player.Name .. ": " .. tostring(err))
		end
		finalizing[player] = nil
	elseif finalizing[player] then
		local t0 = os.clock()
		while finalizing[player] and os.clock() - t0 < FINALIZE_WAIT do
			task.wait(0.1)
		end
		return
	elseif ready[player] then
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
	leftFired[player] = nil
	Util.ClearPlayer(player)
	lastActive[player] = nil
	regularMinutes[player] = nil
	characterLoading[player] = nil
	respawnQueued[player] = nil
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

-- CR-M20: os.clock() of the player's last input/combat (MarkActive); 0 = none yet on this server
function PlayerService.GetLastActive(player)
	return (player ~= nil and lastActive[player]) or 0
end

-- CR-M2: true once BindToClose started (the server is shutting down; leaves are not the players' choice)
function PlayerService.IsShuttingDown()
	return closing
end

-- CR-M4: anti-collusion pair cooldown kept in the HOLDER's save (key "<kind>:<otherUserId>" = os.time()), so it
-- follows the player across servers. true = the last commit is at least `cooldown` s old (or there is none);
-- commit ~= false records now on true. false when the holder has no loaded data (no reward).
function PlayerService.PairReady(holder, otherUserId, kind, cooldown, commit)
	if holder == nil or otherUserId == nil or type(kind) ~= "string" then return false end
	local d = S.DataService.Get(holder)
	if type(d) ~= "table" then return false end
	if type(d.PairCD) ~= "table" then d.PairCD = {} end
	local cd = d.PairCD
	local k = kind .. ":" .. tostring(otherUserId)
	local now = os.time()
	local last = tonumber(cd[k]) or 0
	if last ~= last then last = 0 end
	local need = tonumber(cooldown) or 0
	if need ~= need then need = 0 end
	if now - last < need then return false end
	if commit ~= false then
		local isNew = cd[k] == nil
		cd[k] = now
		if isNew then
			-- bound growth within a long session too (PlayerReady prunes the rest)
			local n = 0
			for _ in cd do
				n += 1
			end
			if n > PAIR.MaxKeys then
				local okPrune, errPrune = pcall(prunePairCD, d)
				if not okPrune then loopWarn("PairCD prune", errPrune) end
			end
		end
	end
	return true
end

function PlayerService.GetRegularMinutes(player)
	return regularMinutes[player] or 0
end

return PlayerService
