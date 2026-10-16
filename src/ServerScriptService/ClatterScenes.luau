-- ClatterScenes.luau : SPEC A23-212 (user 2026-10-16, GPT build/codex/story_world_r5.md §4 B; 게임성 개발 2). Captain Clatter,
-- who broke the Crown by mistake, is the three sides' crown-repair companion. In the first 10 minutes the player meets him
-- three times on the path they already walk - no accept, no trip, no reward, no score, no toast - each ONCE per character
-- (saved first: data.Story.First["Clatter" .. key]) and seen by that player only (their own progress):
--   Sorry  the first departure with the side's guide (TutorialStep leaves 0: the guide's [Accept]) - beside the guide
--   Hat    the first Slime Prince beaten (StoryQuestService.StepDone of M1_1's Kill step) - at the edge, beside the player
--   Carry  the first skill learned (StepDone of M1_3's Learn step) - beside the player, the road out ahead
-- Each = Fx StoryScene { Id = "Clatter", Key = <scene>, Value = "Clatter", Pos = where he stands, Look = what he faces } to that
-- player. The client (game dev 1) puts a LOCAL copy of ReplicatedStorage[Config.StoryQuests.Clatter.Folder].ClatterTown at Pos
-- (on the ground), plays the scene's Move and says its Line (Config, never sent), then lets him go (Stay s). The town body is
-- a copy of the ruins boss model (ServerStorage CustomModels.CaptainClatter): anchored, no collision, no scripts / humanoid,
-- tagged Config.StoryQuests.NpcTag with NpcId "Clatter" (no prompt: nothing to talk through). No model = the scenes still
-- fire (the client may skip the body).
--   ClatterScenes.Play(player, key) -> true when the scene was sent (public for the offline test)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ClatterScenes = {}
local S = nil
local TAG = "ClatterScenes"
local K = Config.StoryQuests.Clatter
local ST = { Watch = {} } -- Watch[player] = the TutorialStep connection

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function on()
	return type(K) == "table" and K.Enabled == true and type(K.Scenes) == "table"
end

-- the guide body of the player's side (the StoryNpc tagged model whose NpcId is Config.Tutorial.Guides[side])
local function guideRoot(player)
	local id = Config.Tutorial.Guides[player:GetAttribute("Faction") or ""]
	if type(id) ~= "string" then return nil end
	for _, m in CollectionService:GetTagged(Config.StoryQuests.NpcTag) do
		if m:GetAttribute("NpcId") == id then
			if m:IsA("Model") then
				if m.PrimaryPart then return m.PrimaryPart end
			elseif m:IsA("BasePart") or m:IsA("Part") then
				return m
			end
		end
	end
	return nil
end

-- where he stands (flat): from the guide toward the player (Sorry) or along the player's facing, Ahead studs on and Side
-- studs to the right of that line; he faces the player
local function placeFor(player, key)
	local root = Util.GetRoot(player)
	if not root then return nil end
	local base = (key == "Sorry" and guideRoot(player)) or root
	local from = base.Position
	local dx, dz
	if base ~= root then
		dx, dz = root.Position.X - from.X, root.Position.Z - from.Z
	else
		local look = root.CFrame.LookVector
		dx, dz = look.X, look.Z
	end
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.01 then dx, dz, len = 0, -1, 1 end
	dx, dz = dx / len, dz / len
	local side, ahead = num(K.Side, 6), num(K.Ahead, 3)
	return Vector3.new(from.X + dx * ahead - dz * side, from.Y, from.Z + dz * ahead + dx * side), root.Position
end

function ClatterScenes.Play(player, key)
	if not on() or type(K.Scenes[key]) ~= "table" or typeof(player) ~= "Instance" then return false end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return false end
	if type(data.Story) ~= "table" then data.Story = {} end
	if type(data.Story.First) ~= "table" then data.Story.First = {} end
	local first = "Clatter" .. key
	if data.Story.First[first] == true then return false end
	local pos, look = placeFor(player, key)
	if not pos then return false end
	data.Story.First[first] = true -- saved first: once per character, even if the Fx is lost
	local ok, err = pcall(Net.Fx, player, "StoryScene", { Id = "Clatter", Key = key, Value = "Clatter", Pos = pos, Look = look })
	if not ok then Util.Warn(TAG, "scene: " .. tostring(err)) end
	return true
end

-- StepDone(player, quest id, step number): the scene whose After = { Quest, Type } is that step
local function onStep(player, id, n)
	if not on() then return end
	local def = Config.StoryQuests.Defs[id]
	local step = type(def) == "table" and type(def.Steps) == "table" and def.Steps[n] or nil
	local t = type(step) == "table" and type(step.Obj) == "table" and step.Obj.Type or nil
	for key, sc in K.Scenes do
		local after = sc.After
		if type(after) == "table" and after.Quest == id and after.Type == t then ClatterScenes.Play(player, key) end
	end
end

-- the first departure: the player's TutorialStep leaves Config.Tutorial.Steps.Kill (0, waiting at the guide) live
local function watch(player)
	if ST.Watch[player] then return end
	local last = player:GetAttribute("TutorialStep")
	ST.Watch[player] = player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
		local now = player:GetAttribute("TutorialStep")
		local was = last
		last = now
		if was == Config.Tutorial.Steps.Kill and now ~= was and now ~= nil then
			local ok, err = pcall(ClatterScenes.Play, player, "Sorry")
			if not ok then Util.Warn(TAG, "Sorry: " .. tostring(err)) end
		end
	end)
end

-- the town body: a copy of the ruins boss model, made once (a later Studio import is not picked up until the next server)
local function ensureBody()
	local src = ServerStorage:FindFirstChild((Config.CustomModels or {}).FolderName or "CustomModels")
	local model = src and src:FindFirstChild(K.Model or "CaptainClatter")
	local folder = Util.GetFolder(ReplicatedStorage, K.Folder or "StoryProps")
	if folder:FindFirstChild("ClatterTown") or not model then return end
	local body = model:Clone()
	if body:IsA("BasePart") then
		local wrap = Instance.new("Model")
		body.Parent = wrap
		wrap.PrimaryPart = body
		body = wrap
	end
	for _, d in body:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
		end
	end
	body.Name = "ClatterTown"
	body:SetAttribute("NpcId", "Clatter")
	CollectionService:AddTag(body, Config.StoryQuests.NpcTag)
	body.Parent = folder
end

function ClatterScenes.Init(registry)
	S = registry
end

function ClatterScenes.Start()
	if not on() then
		print("[ClatterScenes] started (off)")
		return
	end
	local ok, err = pcall(ensureBody)
	if not ok then Util.Warn(TAG, "body: " .. tostring(err)) end
	local sq = S.StoryQuestService
	if sq and sq.StepDone and type(sq.StepDone.Connect) == "function" then
		sq.StepDone:Connect(function(player, id, n)
			local okS, errS = pcall(onStep, player, id, n)
			if not okS then Util.Warn(TAG, "step: " .. tostring(errS)) end
		end)
	else
		Util.Warn(TAG, "missing signal StoryQuestService.StepDone")
	end
	S.PlayerService.PlayerReady:Connect(function(player)
		local okW, errW = pcall(watch, player)
		if not okW then Util.Warn(TAG, "watch: " .. tostring(errW)) end
	end)
	if S.PlayerService.PlayerLeaving then
		S.PlayerService.PlayerLeaving:Connect(function(player)
			local c = ST.Watch[player]
			if c then c:Disconnect() end
			ST.Watch[player] = nil
		end)
	end
	print("[ClatterScenes] started")
end

return ClatterScenes
