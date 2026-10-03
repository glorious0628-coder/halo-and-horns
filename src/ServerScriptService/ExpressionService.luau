-- Three approved expressions: neutral at rest, serious while attacking/hurt, a soft smile during conversation.
-- Only server gameplay events choose a face. Original personal avatars are never modified.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local Assets = require(ReplicatedStorage.Shared.ExpressionAssets)
local Util = require(ReplicatedStorage.Shared.Util)
local SkinContract = require(script.Parent.ExpressionSkinContract)

local ExpressionService = {}
local S
local states = {}
local monsters = {}
local DURATION = { Attack = 1.2, Hurt = 0.8, Talk = 3, Tick = 0.1 }
local RUNTIME = { Chat = {}, CharacterRemoving = {}, Active = {}, Folder = nil, FolderConns = {}, Started = false }

local function assetId(value)
	if type(value) ~= "string" then return false end
	local digits = value:match("^rbxassetid://(%d+)$")
	return digits ~= nil and #digits <= 20 and digits:find("[1-9]") ~= nil
end

local function complete(def)
	return type(def) == "table" and assetId(def.Neutral) and assetId(def.Serious) and assetId(def.SoftSmile)
end

local function clearConnections(list)
	for _, connection in list do connection:Disconnect() end
	table.clear(list)
end

local function dispose(st)
	RUNTIME.Active[st] = nil
	clearConnections(st.Conns)
	if st.Player and states[st.Player] == st then states[st.Player] = nil end
	if monsters[st.Model] == st then monsters[st.Model] = nil end
end

local function directWeld(weld, model, head, mesh)
	if not weld or not weld.Parent or not weld:IsDescendantOf(model)
		or not (weld:IsA("Weld") or weld:IsA("WeldConstraint")) then return false end
	local ok, connected = pcall(function()
		local enabledOK, enabled = pcall(function() return weld.Enabled end)
		if enabledOK and enabled == false then return false end
		return (weld.Part0 == head and weld.Part1 == mesh) or (weld.Part0 == mesh and weld.Part1 == head)
	end)
	return ok and connected
end

local function faceMesh(model, head, def)
	-- Expression atlases use a separate, verified UV mesh. Never replace the original Head atlas.
	local name = type(def) == "table" and def.MeshName
	if type(name) ~= "string" or #name == 0 or #name > 64 or name:find("[^%w_%-]") or name == "Head" then return nil end
	local mesh
	for _, child in model:GetDescendants() do
		if child.Name == name then
			if mesh or not child:IsA("MeshPart") then return nil end -- duplicate/ambiguous names fail closed
			mesh = child
		end
	end
	if not mesh or mesh:GetAttribute("HHC_ExpressionMeshValidated") ~= true
		or mesh:FindFirstChildOfClass("SurfaceAppearance") then return nil end
	if head and def.SkinSchema ~= nil then
		local ok, context = pcall(SkinContract.Bind, model, head, mesh, def)
		if not ok then return nil end
		return context and mesh or nil, nil, context
	end
	if not head then return mesh end -- monster-owned target, still marked and scoped to this model
	if mesh:IsDescendantOf(head) then return mesh end
	for _, child in model:GetDescendants() do
		if directWeld(child, model, head, mesh) then return mesh, child end
	end
	return nil
end

local function meshReady(st)
	local mesh = st.Mesh
	if not complete(st.Assets) or not mesh or not mesh.Parent or not mesh:IsDescendantOf(st.Model)
		or mesh:GetAttribute("HHC_ExpressionMeshValidated") ~= true
		or mesh:FindFirstChildOfClass("SurfaceAppearance") then return false end
	if st.Assets.SkinSchema ~= nil then
		local ok, ready = pcall(SkinContract.IsReady, st.SkinContext)
		return ok and ready == true
	end
	return not st.Head or mesh:IsDescendantOf(st.Head) or directWeld(st.Weld, st.Model, st.Head, mesh)
end

local function choose(st, now)
	if now < st.HurtUntil or now < st.AttackUntil then return "Serious" end
	if now < st.TalkUntil then return "SoftSmile" end
	return "Neutral"
end

local function draw(st, now)
	local model = st.Model
	if not model or not model.Parent or (st.Player and (st.Player.Character ~= model
		or model:GetAttribute("HHC_CostumeId") ~= st.CostumeId))
		or (st.Folder and (model.Parent ~= st.Folder or st.Folder.Parent ~= workspace)) then
		dispose(st)
		return
	end
	local expression = choose(st, now)
	if expression == "Neutral" then RUNTIME.Active[st] = nil else RUNTIME.Active[st] = true end
	local ready = meshReady(st)
	if st.Current == expression and st.Ready == ready then return end
	if ready then
		ready = pcall(function()
			if st.Mesh.TextureID ~= st.Assets[expression] then st.Mesh.TextureID = st.Assets[expression] end
		end)
	end
	st.Current, st.Ready = expression, ready
	if model:GetAttribute("Expression") ~= expression then model:SetAttribute("Expression", expression) end
	if model:GetAttribute("ExpressionReady") ~= ready then model:SetAttribute("ExpressionReady", ready) end
end

local function state(model, mesh, def)
	return { Model = model, Mesh = mesh, Assets = def, Ready = nil, Current = nil,
		AttackUntil = 0, HurtUntil = 0, TalkUntil = 0, Conns = {} }
end

local function bindCharacter(player, character, humanoid)
	local previous = states[player]
	if previous then dispose(previous) end
	states[player] = nil
	if player.Character ~= character or not S.PlayerService.IsReady(player) or not humanoid or not humanoid:IsA("Humanoid") then return end
	-- OFF restores the owner's Roblox avatar, including their chosen face.
	local id = character:GetAttribute("HHC_CostumeId")
	if type(id) ~= "string" or id == "" then return end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	-- PBR assets require prebuilt SurfaceAppearance variants, never a protected ColorMap write at runtime.
	local def = Assets.Costumes[id]
	local mesh, weld, context = faceMesh(character, head, def)
	local st = state(character, mesh, def)
	st.Player, st.CostumeId, st.Head, st.Weld = player, id, head, weld
	st.SkinContext = context
	st.Health = humanoid.Health
	states[player] = st
	table.insert(st.Conns, humanoid.HealthChanged:Connect(function(health)
		if states[player] ~= st then return end
		if health > 0 and health < st.Health then st.HurtUntil = os.clock() + DURATION.Hurt end
		st.Health = health
		draw(st, os.clock())
	end))
	table.insert(st.Conns, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then dispose(st) end
	end))
	draw(st, os.clock())
end

function ExpressionService.Attack(player)
	local st = states[player]
	if not st or player.Character ~= st.Model or not Util.IsAlive(player) then return end
	st.AttackUntil = os.clock() + DURATION.Attack
	draw(st, os.clock())
end

function ExpressionService.Talk(player)
	local st = states[player]
	if not st or player.Character ~= st.Model or not Util.IsAlive(player) then return end
	st.TalkUntil = os.clock() + DURATION.Talk
	draw(st, os.clock())
end

local function bindPlayer(player)
	if player.Parent ~= Players or RUNTIME.Chat[player] then return end
	local connection = player.Chatted:Connect(function()
		-- No message content is stored or broadcast here; Roblox owns the chat filtering.
		if S.PlayerService.IsReady(player) then ExpressionService.Talk(player) end
	end)
	RUNTIME.Chat[player] = connection
	RUNTIME.CharacterRemoving[player] = player.CharacterRemoving:Connect(function(character)
		local st = states[player]
		if st and st.Model == character then dispose(st) end
	end)
end

local function unbindPlayer(player)
	local st = states[player]
	if st then dispose(st) end
	local connection = RUNTIME.Chat[player]
	RUNTIME.Chat[player] = nil
	if connection then connection:Disconnect() end
	connection = RUNTIME.CharacterRemoving[player]
	RUNTIME.CharacterRemoving[player] = nil
	if connection then connection:Disconnect() end
end

local function bindMonster(model)
	if not model:IsA("Model") or model.Parent ~= RUNTIME.Folder or monsters[model] then return end
	local kind = model:GetAttribute("MonsterKind")
	if type(kind) ~= "string" then return end
	local def = Assets.Monsters[kind]
	local mesh = faceMesh(model, nil, def)
	local st = state(model, mesh, def)
	st.Folder = RUNTIME.Folder
	st.Sequences = { AttackSeq = tonumber(model:GetAttribute("AttackSeq")) or 0,
		HurtSeq = tonumber(model:GetAttribute("HurtSeq")) or 0 }
	monsters[model] = st
	for _, attribute in { "WindupAt", "AttackSeq" } do
		table.insert(st.Conns, model:GetAttributeChangedSignal(attribute):Connect(function()
			local value = model:GetAttribute(attribute)
			if type(value) ~= "number" or value < 0 or value ~= value or value == math.huge then return end
			if attribute == "AttackSeq" then
				local previousSeq = st.Sequences.AttackSeq
				st.Sequences.AttackSeq = value
				if value == 0 or value <= previousSeq then return end
			end
			if value == 0 then return end
			st.AttackUntil = os.clock() + DURATION.Attack
			draw(st, os.clock())
		end))
	end
	table.insert(st.Conns, model:GetAttributeChangedSignal("HurtSeq"):Connect(function()
		local value = model:GetAttribute("HurtSeq")
		if type(value) ~= "number" or value < 0 or value ~= value or value == math.huge then return end
		local previousSeq = st.Sequences.HurtSeq
		st.Sequences.HurtSeq = value
		if value == 0 or value <= previousSeq then return end
		st.HurtUntil = os.clock() + DURATION.Hurt
		draw(st, os.clock())
	end))
	table.insert(st.Conns, model.AncestryChanged:Connect(function()
		if model.Parent ~= st.Folder then dispose(st) end
	end))
	draw(st, os.clock())
end

local function watchMonsterFolder(folder)
	if not folder or not folder:IsA("Folder") or folder.Name ~= "Monsters" or folder.Parent ~= workspace
		or RUNTIME.Folder == folder or (RUNTIME.Folder and RUNTIME.Folder.Parent == workspace) then return end
	clearConnections(RUNTIME.FolderConns)
	RUNTIME.Folder = folder
	table.insert(RUNTIME.FolderConns, folder.ChildAdded:Connect(bindMonster))
	table.insert(RUNTIME.FolderConns, folder.AncestryChanged:Connect(function()
		if folder.Parent == workspace then return end
		if RUNTIME.Folder == folder then
			RUNTIME.Folder = nil
			clearConnections(RUNTIME.FolderConns)
			for _, st in monsters do if st.Folder == folder then dispose(st) end end
			watchMonsterFolder(workspace:FindFirstChild("Monsters"))
		end
	end))
	for _, model in folder:GetChildren() do bindMonster(model) end
end

local function conversationPrompt(prompt, player)
	if not prompt:IsA("ProximityPrompt") or not prompt:IsDescendantOf(workspace) then return end
	local owner = prompt:FindFirstAncestorOfClass("Model")
	-- A shop/altar prompt on a generic NPC is not proof that a conversation started.
	if prompt:GetAttribute("Conversation") ~= true or not owner or not CollectionService:HasTag(owner, "NPC") then return end
	if player.Parent ~= Players or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) or not prompt.Enabled then return end
	local root = Util.GetRoot(player)
	local parent = prompt.Parent
	local point = parent and (parent:IsA("Attachment") and parent.WorldPosition
		or (parent:IsA("BasePart") and parent.Position)
		or (parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position))
	if not root or typeof(point) ~= "Vector3" then return end
	local distance, limit = (root.Position - point).Magnitude, prompt.MaxActivationDistance
	if distance ~= distance or distance == math.huge or limit ~= limit or limit < 0 or limit == math.huge
		or distance > limit + 3 then return end
	if not Util.RateLimit(player, "ExpressionConversation", 0.5) then return end
	ExpressionService.Talk(player)
end

function ExpressionService.Init(registry)
	S = registry
end

function ExpressionService.Start()
	if RUNTIME.Started then return end
	RUNTIME.Started = true
	for _, player in Players:GetPlayers() do bindPlayer(player) end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(unbindPlayer) -- PlayerLeaving is not fired when someone leaves before DataLoaded
	S.PlayerService.CharacterSpawned:Connect(bindCharacter)
	S.PlayerService.PlayerLeaving:Connect(unbindPlayer)
	ProximityPromptService.PromptTriggered:Connect(conversationPrompt)
	-- Init normally creates this folder; also handle a late/rebuilt folder without a world scan.
	watchMonsterFolder(workspace:FindFirstChild("Monsters"))
	workspace.ChildAdded:Connect(watchMonsterFolder)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < DURATION.Tick then return end
		elapsed = 0
		local now = os.clock()
		-- Only timed non-neutral states need a expiry tick; idle avatars/monsters cost no per-frame scans.
		for st in RUNTIME.Active do draw(st, now) end
	end)
	print("[ExpressionService] started")
end

return ExpressionService
