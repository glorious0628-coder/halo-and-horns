-- PetFollow.luau : PET-3 (A23-39, docs/design/pet_tamer_server_2026-10-06.md section 4). Every player's equipped pet
-- follows its owner, drawn by each client (pets are never targets: they live in workspace.ClientPets, outside the
-- Monsters folder and the characters). Model: ReplicatedStorage.PetModels.<species> (PetService copies
-- ServerStorage.CustomModels.Pet<species> there); no model yet -> nothing, silently. Player attributes: EquippedPet
-- (species id or ""), PetLv, PetForm.
-- The pet floats behind my right shoulder, hops while it moves and snaps back after a teleport. Fx drives the attack
-- moves of the pet tamer: PetFollow.Attack(userId, targets, contact) for "PetHeadbutt" (runs to each target, bumps it
-- at the contact time, comes back) and PetFollow.Dash(userId, pos, contact) for "PetDash" (skill Q).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetFollow = {}
local TAG = "PetFollow"
local LocalPlayer = Players.LocalPlayer

local P = {
	Height = 1.8, -- studs (a baby slime next to a 5-stud avatar)
	Offset = Vector3.new(2.6, 0, 2.4), -- right / up / back of the owner
	Follow = 8, -- position smoothing per second
	Snap = 40, -- studs: farther than this from the follow spot = jump there (teleport, respawn)
	HopHeight = 0.5, HopRate = 9, -- hop while moving
	Range = 160, -- studs from the camera; farther pets are hidden
	Back = 0.3, -- s to run back after a bump
	Bump = 0.12, -- s the bump squash lasts at the target
	RayEvery = 0.25, -- s between ground rays per pet
}
local S = { Started = false, Pets = {}, Folder = nil, Models = nil, Warned = {} } -- Pets[userId] = state

local function warnOnce(key, msg)
	if S.Warned[key] then return end
	S.Warned[key] = true
	warn("[" .. TAG .. "] " .. msg)
end

local function folder()
	if S.Folder and S.Folder.Parent then return S.Folder end
	local f = workspace:FindFirstChild("ClientPets")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClientPets"
		f.Parent = workspace
	end
	S.Folder = f
	return f
end

local function template(species)
	local models = S.Models or ReplicatedStorage:FindFirstChild("PetModels")
	S.Models = models
	local t = models and models:FindFirstChild(species)
	if t and (t:IsA("Model") or t:IsA("BasePart")) then return t end
	return nil
end

local function groundY(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position.Y or nil
end

local function destroyPet(uid)
	local st = S.Pets[uid]
	if not st then return end
	S.Pets[uid] = nil
	if st.Model then st.Model:Destroy() end
end

-- (re)builds the pet of a player from its EquippedPet attribute
local function rebuild(player)
	local uid = player.UserId
	local species = player:GetAttribute("EquippedPet")
	local st = S.Pets[uid]
	if type(species) ~= "string" or species == "" then
		destroyPet(uid)
		return
	end
	if st and st.Species == species and st.Model and st.Model.Parent then return end
	destroyPet(uid)
	local t = template(species)
	if not t then return end -- the model is not replicated yet (PetService copy): try again on the next change
	local m = t:Clone()
	if m:IsA("BasePart") then
		local holder = Instance.new("Model")
		m.Parent = holder
		holder.PrimaryPart = m
		m = holder
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = true, false, false, false, true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local _, size = m:GetBoundingBox()
	if size.Y > 0.01 then pcall(m.ScaleTo, m, m:GetScale() * P.Height / size.Y) end
	m.Name = "Pet_" .. tostring(uid)
	m:SetAttribute("OwnerUserId", uid)
	m.Parent = folder()
	local _, s2 = m:GetBoundingBox()
	S.Pets[uid] = { Player = player, Species = species, Model = m, Half = s2.Y / 2, Pos = nil, Y = nil, RayAt = 0,
		Action = nil, Moving = 0, Phase = math.random() * 6 }
end

local function watch(player)
	player:GetAttributeChangedSignal("EquippedPet"):Connect(function()
		local ok, err = pcall(rebuild, player)
		if not ok then warnOnce("rebuild", "rebuild failed: " .. tostring(err)) end
	end)
	task.defer(function() pcall(rebuild, player) end)
end

-- the follow spot of an owner (behind-right, on the ground under it)
local function spot(st, root)
	local cf = root.CFrame
	local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit
	local right = flat:Cross(Vector3.yAxis)
	return root.Position + right * P.Offset.X - flat * P.Offset.Z
end

local function step(dt)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local now = os.clock()
	for uid, st in S.Pets do
		local player = st.Player
		local char = player.Parent and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local m = st.Model
		if not m or not m.Parent then
			S.Pets[uid] = nil
			continue
		end
		if not root then
			m:PivotTo(CFrame.new(0, -500, 0))
			continue
		end
		local far = camPos and (root.Position - camPos).Magnitude > P.Range
		if far then
			if not st.Hidden then
				st.Hidden = true
				m:PivotTo(CFrame.new(0, -500, 0))
			end
			continue
		end
		st.Hidden = false
		local goal = spot(st, root)
		local a = st.Action
		local face = nil
		if a then
			local t = now - a.T0
			local target = a.Targets[math.clamp(math.floor(t / a.Each) + 1, 1, #a.Targets)]
			local into = (t % a.Each)
			if t >= a.Each * #a.Targets + P.Back then
				st.Action = nil
			elseif t < a.Each * #a.Targets then
				-- run to the target, arrive at the contact time, a small squash there
				local k = math.clamp(into / math.max(0.05, a.Contact), 0, 1)
				local from = st.Pos or goal
				goal = from:Lerp(target, k * k)
				face = target
			end
		end
		local pos = st.Pos or goal
		if (goal - pos).Magnitude > P.Snap then pos = goal end
		local alpha = a and 1 or (1 - math.exp(-P.Follow * dt))
		local nextPos = pos:Lerp(goal, alpha)
		local moved = (Vector3.new(nextPos.X, 0, nextPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		st.Moving = math.max(0, st.Moving - dt) + (moved > 0.02 and dt * 2 or 0)
		st.Pos = nextPos
		if now >= st.RayAt then
			st.RayAt = now + P.RayEvery
			local y = groundY(nextPos, { S.Folder, char })
			if y then st.Y = y end
		end
		local y = (st.Y or (root.Position.Y - 3)) + st.Half
		local hop = st.Moving > 0.05 and math.abs(math.sin((now + st.Phase) * P.HopRate)) * P.HopHeight or 0
		local look = face or (goal + (root.CFrame.LookVector * Vector3.new(1, 0, 1)))
		local at = Vector3.new(nextPos.X, y + hop, nextPos.Z)
		local dir = Vector3.new(look.X - at.X, 0, look.Z - at.Z)
		local cf = dir.Magnitude > 0.05 and CFrame.lookAt(at, at + dir) or CFrame.new(at)
		m:PivotTo(cf)
	end
end

-- 'PetHeadbutt': the pet runs to each target and bumps it at the contact time, then comes back.
-- Returns false when that player has no pet drawn (Fx then shows the punch instead).
function PetFollow.Attack(userId, targets, contact)
	local st = S.Pets[userId]
	if not st or not st.Model or not st.Model.Parent or st.Hidden then return false end
	local list = {}
	for _, v in type(targets) == "table" and targets or {} do
		if typeof(v) == "Vector3" then table.insert(list, v) end
		if #list >= 2 then break end
	end
	if #list == 0 then return false end
	local c = math.clamp(tonumber(contact) or 0.3, 0.05, 1)
	st.Action = { Targets = list, T0 = os.clock(), Contact = c, Each = c + P.Bump }
	return true
end

-- 'PetDash' (skill Q): one fast run to the impact point
function PetFollow.Dash(userId, pos, contact)
	if typeof(pos) ~= "Vector3" then return false end
	return PetFollow.Attack(userId, { pos }, contact)
end

function PetFollow.Has(userId)
	local st = S.Pets[userId]
	return st ~= nil and st.Model ~= nil and st.Model.Parent ~= nil and not st.Hidden
end

function PetFollow.Init(_registry) end

function PetFollow.Start()
	if S.Started then return end
	S.Started = true
	for _, p in Players:GetPlayers() do watch(p) end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p) destroyPet(p.UserId) end)
	-- the models arrive later than the players when PetService copies them after start
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("PetModels", 60)
		if not models then return end
		S.Models = models
		models.ChildAdded:Connect(function()
			for _, p in Players:GetPlayers() do pcall(rebuild, p) end
		end)
		for _, p in Players:GetPlayers() do pcall(rebuild, p) end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then warnOnce("step", "step failed: " .. tostring(err)) end
	end)
	print("[PetFollow] started")
end

return PetFollow
