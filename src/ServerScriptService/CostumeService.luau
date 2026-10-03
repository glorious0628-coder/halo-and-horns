-- CostumeService.luau: server-owned 18-way appearance selection and actual animated R15 character rigs.
-- Static imported GLBs are never treated as playable rigs. Missing/invalid rigs keep the owner's Roblox avatar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local CostumeService = {}
local S = nil
local states = {}
local TAG = "CostumeService"
local ATTR = { Costume = "HHC_CostumeId", Original = "HHC_OriginalRestore" }
local FACTIONS = { Halo = true, Horns = true, Neutral = true }
local CLASSES = { Warrior = true, Mage = true, Archer = true }
local BODY = {
	"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local EDGES = {
	{ "HumanoidRootPart", "LowerTorso" }, { "LowerTorso", "UpperTorso" }, { "UpperTorso", "Head" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local function setStatus(player, status)
	if player.Parent ~= Players then return end
	player:SetAttribute("CostumeStatus", status)
	local character = player.Character
	player:SetAttribute("CostumeApplied", character ~= nil and character:GetAttribute(ATTR.Costume) ~= nil)
end

local function ensureState(player)
	local st = states[player]
	if not st then
		st = { Pending = false, Busy = false, Version = 0, Animations = {}, Conns = {} }
		states[player] = st
	end
	return st
end

local function desiredId(player)
	local d = S.PlayerService.GetData(player)
	if not d or d.CostumeEnabled == false or d.ClassChosen ~= true then return nil end
	if not FACTIONS[d.Faction] or not CLASSES[d.Class] then return nil end
	local gender = d.CharacterGender == "F" and "F" or "M"
	local prefix = (Config.Costumes and Config.Costumes.TemplatePrefix) or "Costume_"
	return prefix .. d.Faction .. d.Class .. gender
end

-- Complete R15 graph, not a torso with a welded decorative statue. Standard Animate needs all 15 body joints.
function CostumeService.ValidateTemplate(template)
	if typeof(template) ~= "Instance" or not template:IsA("Model") then return false, "MissingTemplate" end
	local humanoid = template:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 or humanoid.Health <= 0 then return false, "InvalidRig" end
	local parts = {}
	for _, name in BODY do
		local part = template:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then return false, "InvalidRig" end
		parts[name] = part
	end
	local joints = {}
	for _, child in template:GetDescendants() do
		if child:IsA("Motor6D") then table.insert(joints, child) end
	end
	for _, edge in EDGES do
		local found = false
		for _, joint in joints do
			if joint.Enabled and joint.Part0 == parts[edge[1]] and joint.Part1 == parts[edge[2]] then found = true; break end
		end
		if not found then return false, "InvalidRig" end
	end
	return true
end

local function getTemplate(id)
	local folderName = (Config.Costumes and Config.Costumes.TemplateFolder) or "CostumeRigs"
	local folder = ServerStorage:FindFirstChild(folderName)
	local template = folder and folder:FindFirstChild(id)
	local valid, why = CostumeService.ValidateTemplate(template)
	return valid and template or nil, why
end

local function clone(instance)
	local ok, result = pcall(instance.Clone, instance)
	return ok and result or nil
end

local function prepareCharacter(player, character)
	local st = states[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not st or not humanoid or not root or not root:IsA("BasePart") then return false end
	local source = st.Animations[humanoid.RigType]
	if not source or not source:IsA("LocalScript") then
		-- Populate this server-owned folder only with verified Roblox controllers from a default R15/R6 dummy.
		-- A cached R6 owner's Animate cannot animate an R15 costume; use the known R15 controller instead.
		local controllers = ServerStorage:FindFirstChild("CostumeAnimationControllers")
		source = controllers and controllers:FindFirstChild(humanoid.RigType.Name)
		-- The installer marks a verified, complete default controller. A manually supplied Starter Animate
		-- has no proven rig type and must not silently override the known R15 controller.
		local hash = source and source:GetAttribute("CaptureSourceSHA256")
		if not source or source:GetAttribute("CaptureRigType") ~= humanoid.RigType.Name
			or source:GetAttribute("CaptureOrigin") ~= "RobloxDefaultCharacter"
			or type(hash) ~= "string" or #hash ~= 64 or not string.match(hash, "^[0-9a-fA-F]+$") then
			source = nil
		end
	end
	if not source or not source:IsA("LocalScript") then return false end
	local animate = clone(source)
	if not animate then return false end
	-- Template scripts (even a LocalScript named Animate and everything below it) carry no trust marker.
	-- Remove all of them before installing the known game-owned controller and StarterCharacterScripts.
	for _, child in character:GetDescendants() do
		if child:IsA("LuaSourceContainer") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
		end
	end
	local oldAnimate = character:FindFirstChild("Animate")
	if oldAnimate then oldAnimate:Destroy() end
	animate.Name = "Animate"
	animate.Parent = character
	for _, source in StarterPlayer.StarterCharacterScripts:GetChildren() do
		if not character:FindFirstChild(source.Name) then
			local copied = clone(source)
			if copied then copied.Parent = character end
		end
	end
	if not humanoid:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = humanoid -- server creation allows animation replication to all players
	end
	-- Custom Motor6D costumes use the verified template's non-colliding root. An engine-created
	-- owner avatar may use an AnimationConstraint/controller collision profile with a colliding
	-- root. Keep that native profile intact; the remaining OFF lifecycle issue is validated separately.
	-- Preserve every native body/accessory collision and joint setting when costume is OFF.
	if character:GetAttribute(ATTR.Costume) then root.CanCollide = false end
	humanoid.PlatformStand = false
	character.PrimaryPart = root
	animate.Disabled = false
	return true
end

local function captureOriginal(player, character)
	if player.Parent ~= Players or player.Character ~= character or character:GetAttribute(ATTR.Costume) then return end
	local st = states[player]
	if not st then return end
	-- CharacterAdded precedes appearance loading; snapshot only the fully dressed owner avatar.
	if not character:GetAttribute(ATTR.Original) then
		local ok, loaded = pcall(player.HasAppearanceLoaded, player)
		if not ok or not loaded then return end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 5)
	if states[player] ~= st or player.Character ~= character or not humanoid then return end
	if animate and animate:IsA("LocalScript") then
		local copied = clone(animate)
		if copied then
			local previous = st.Animations[humanoid.RigType]
			st.Animations[humanoid.RigType] = copied
			if previous then previous:Destroy() end
		end
	end
	if not character:GetAttribute(ATTR.Original) then
		local ok, description = pcall(humanoid.GetAppliedDescription, humanoid)
		if ok and description then
			if st.OriginalDescription then st.OriginalDescription:Destroy() end
			st.OriginalDescription = description
			st.OriginalRigType = humanoid.RigType
		end
	end
	CostumeService.RequestRefresh(player)
end

function CostumeService.CreateSpawnCharacter(player)
	local id = desiredId(player)
	if not id then return nil end
	local st = states[player]
	-- Capture the owner's actual avatar once first, so OFF always restores their own clothes/accessories/rig type.
	if not st or not st.OriginalDescription then setStatus(player, "WaitingAppearance"); return nil end
	local template, why = getTemplate(id)
	if not template then setStatus(player, why or "MissingTemplate"); return nil end
	local character = clone(template)
	if not character then setStatus(player, "Error"); return nil end
	character:SetAttribute(ATTR.Costume, id)
	if not prepareCharacter(player, character) then
		character:Destroy()
		setStatus(player, "WaitingAnimation")
		return nil
	end
	return character
end

local function blocked(player)
	if S.PlayerService.IsSpawning(player) or not Util.IsAlive(player) then return true end
	if S.CombatService and S.CombatService.IsInCombat(player) then return true end
	if S.KaijuService and S.KaijuService.GetState(player) ~= "None" then return true end
	return false
end

local function refresh(player, st, version)
	if states[player] ~= st or not S.PlayerService.IsReady(player) then return false end
	if blocked(player) then setStatus(player, "Deferred"); return true end
	local old = player.Character
	local currentId = old:GetAttribute(ATTR.Costume)
	local id = desiredId(player)
	if id and currentId == id then setStatus(player, "Active"); return false end
	local character = id and CostumeService.CreateSpawnCharacter(player) or nil
	local status = id and "Active" or "Avatar"
	if id and not character then status = player:GetAttribute("CostumeStatus") or "MissingTemplate" end
	if not character then
		if not currentId then setStatus(player, status); return false end
		local restored = S.PlayerService.RestoreOwnerCharacter(player, st.OriginalDescription, old, function()
			return states[player] == st and st.Version == version and player.Character == old and not blocked(player)
		end)
		if states[player] ~= st then return false end
		setStatus(player, restored and status or "Error")
		return not restored and player.Character == old
	end
	-- Discard stale requests, leaving players, changed/dead characters.
	if states[player] ~= st or st.Version ~= version or player.Character ~= old or blocked(player) then
		character:Destroy()
		return states[player] == st
	end
	local installed = S.PlayerService.ReplaceCharacter(player, character, old)
	if not installed then character:Destroy(); return true end
	setStatus(player, status)
	return false
end

function CostumeService.RequestRefresh(player)
	if not S.PlayerService.IsReady(player) or player.Parent ~= Players then return end
	local st = ensureState(player)
	st.Version += 1
	st.Pending = true
end

local function onSetCostume(player, enabled, gender)
	if not S.PlayerService.IsReady(player) then return end
	if type(enabled) ~= "boolean" or (gender ~= nil and gender ~= "M" and gender ~= "F") then return end
	if not Util.RateLimit(player, "SetCostume", Config.RateLimits.SetCostume or 1) then return end
	S.PlayerService.SetStat(player, "CostumeEnabled", enabled)
	if gender ~= nil then S.PlayerService.SetStat(player, "CharacterGender", gender) end
	S.PlayerService.MarkActive(player)
	CostumeService.RequestRefresh(player)
end

local function onLeaving(player)
	local st = states[player]
	states[player] = nil
	if not st then return end
	for _, conn in st.Conns do conn:Disconnect() end
	for _, animate in st.Animations do animate:Destroy() end
	if st.OriginalDescription then st.OriginalDescription:Destroy() end
end

function CostumeService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		local st = ensureState(player)
		table.insert(st.Conns, player.CharacterAppearanceLoaded:Connect(function(character)
			task.defer(captureOriginal, player, character)
		end))
		setStatus(player, "Avatar")
	end)
	S.PlayerService.CharacterSpawned:Connect(function(player, character)
		if character:GetAttribute(ATTR.Costume) then
			setStatus(player, "Active")
		else
			task.defer(captureOriginal, player, character)
		end
		CostumeService.RequestRefresh(player)
	end)
	S.PlayerService.PlayerLeaving:Connect(onLeaving)
	S.ClassService.ClassChanged:Connect(CostumeService.RequestRefresh)
	S.FactionService.FactionChanged:Connect(CostumeService.RequestRefresh)
end

function CostumeService.Start()
	Net.Get("SetCostume").OnServerEvent:Connect(onSetCostume)
	local watchedControllers = {}
	local function refreshPlayers()
		for player in states do CostumeService.RequestRefresh(player) end
	end
	local function watchController(instance)
		local controllers = ServerStorage:FindFirstChild("CostumeAnimationControllers")
		if not controllers or instance.Parent ~= controllers or not instance:IsA("LocalScript")
			or (instance.Name ~= "R15" and instance.Name ~= "R6") or watchedControllers[instance] then return end
		local connections = {}
		watchedControllers[instance] = connections
		for _, attribute in { "CaptureSourceSHA256", "CaptureRigType", "CaptureOrigin" } do
			table.insert(connections, instance:GetAttributeChangedSignal(attribute):Connect(refreshPlayers))
		end
		table.insert(connections, instance.Destroying:Connect(function()
			for _, connection in connections do connection:Disconnect() end
			watchedControllers[instance] = nil
		end))
	end
	local controllers = ServerStorage:FindFirstChild("CostumeAnimationControllers")
	if controllers then
		for _, instance in controllers:GetChildren() do watchController(instance) end
	end
	ServerStorage.DescendantAdded:Connect(function(instance)
		local folderName = (Config.Costumes and Config.Costumes.TemplateFolder) or "CostumeRigs"
		local folder = ServerStorage:FindFirstChild(folderName)
		local animationFolder = ServerStorage:FindFirstChild("CostumeAnimationControllers")
		if animationFolder and (instance == animationFolder or instance:IsDescendantOf(animationFolder)) then
			watchController(instance)
			refreshPlayers()
		elseif folder and (instance == folder or instance:IsDescendantOf(folder)) then
			refreshPlayers()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, st in states do
				if st.Pending and not st.Busy then
					st.Pending, st.Busy = false, true
					local version = st.Version
					task.spawn(function()
						local ok, retry = pcall(refresh, player, st, version)
						if states[player] ~= st then return end
						st.Busy = false
						if ok then
							if retry then st.Pending = true end
						else
							setStatus(player, "Error")
							Util.Warn(TAG, "appearance refresh failed: " .. tostring(retry))
						end
					end)
				end
			end
		end
	end)
	print("[CostumeService] started")
end

return CostumeService
