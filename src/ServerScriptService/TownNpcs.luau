-- TownNpcs.luau : the town people's bodies (zone_check_halo #22 / #24 / #25 / #26 / #27 / #30 / #34, 검수 2026-10-10; 게임성 개발 3).
-- Called by MapBuilder.Build (ensureStoryNpcs) like the potion seller: temporary default Roblox-style NPCs made from a
-- HumanoidDescription (A23-6: no costume rig, no new art; the final looks come from remake P4), anchored, no collision, no scripts.
-- Config.TownNpcs.List says who stands where (X / Z; the height comes from a downward ray onto the ground, Terrain or the paved
-- terrace, so a body never floats above or sinks into the new Halo terraces) and what each one is:
--   Story   = "Bright": a quest NPC. Tagged Config.StoryQuests.NpcTag ("StoryNpc") with the attribute NpcId and a "Talk"
--             ProximityPrompt (the key is the player's Interact key, Keybinds retargets it) with the attribute StoryNpcId;
--             StoryQuestService.TalkToNpc opens the dialogue of the quest step that is talked through that NPC.
--   Folk    = "Folk1": a townsperson who only stands there (no prompt). Tagged "TownFolk" with the attribute FolkId (the
--             reaction lines of A23-64 attach to these: game dev 2's lines, game dev 1's bubble).
--   Merchant = true: a potion stall seller. Tagged "PotionMerchant" like the Crossroads seller, same prompt, attribute
--             HHC_PotionMerchant; Enabled = false until ShopService accepts more than the one named seller (game dev 2).
--   Anvil   = true: Otto, decorative: he stands behind the Crossroads anvil (the shop prompt stays on the anvil).
-- A model that already exists under the name is reused (its tags, attributes and prompt repaired, moved when its spot changed);
-- nothing here ever deletes anything that is not its own (attribute HHC_TownNpc). Build never yields: the bodies are made in
-- one task after Build returns (the avatar call loads Roblox's default meshes).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local TownNpcs = {}

local TAG = "TownNpcs"

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function finite(v)
	return num(v, nil) ~= nil
end

local function color(c, fallback)
	if typeof(c) == "Color3" then return c end
	return fallback
end

-- the ground height under (x, z): a ray from RayTop straight down that ignores the NPC folder and every player's character;
-- only a floor-like hit counts (a slope or a wall under the point is "no ground")
function TownNpcs.GroundY(x, z, ignore)
	local C = Config.TownNpcs
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = {}
	for _, inst in ignore or {} do table.insert(list, inst) end
	local okPlayers, players = pcall(function() return game:GetService("Players"):GetPlayers() end)
	if okPlayers then
		for _, p in players do
			if p.Character then table.insert(list, p.Character) end
		end
	end
	params.FilterDescendantsInstances = list
	local top = num(C.RayTop, 150)
	local ok, hit = pcall(function()
		return workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top + num(C.RayDepth, 60)), 0), params)
	end)
	if not ok or not hit then return nil end
	if typeof(hit.Normal) ~= "Vector3" or hit.Normal.Y < 0.7 then return nil end
	return hit.Position.Y
end

-- the Crossroads anvil part (the same lookup as ShopService), or nil
local function findAnvil()
	local map = workspace:FindFirstChild("Map")
	local landmarks = map and map:FindFirstChild("Landmarks")
	local guild = landmarks and landmarks:FindFirstChild("ArtisanGuild")
	local anvil = guild and guild:FindFirstChild("Anvil")
	if anvil and anvil:IsA("BasePart") then return anvil end
	return nil
end

-- where an entry stands: { X, Z, LookX, LookZ } or nil (Otto: behind the anvil, away from the Crossroads middle)
function TownNpcs.Spot(entry)
	local C = Config.TownNpcs
	if entry.Anvil == true then
		local anvil = findAnvil()
		if not anvil then return nil end
		local center = Config.Zones.Crossroads.Center
		local dx, dz = anvil.Position.X - center.X, anvil.Position.Z - center.Z
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 1 then return nil end
		local back = num(entry.Behind, 4)
		return { X = anvil.Position.X + dx / len * back, Z = anvil.Position.Z + dz / len * back, LookX = center.X, LookZ = center.Z }
	end
	local at = entry.At
	if typeof(at) ~= "Vector3" or not finite(at.X) or not finite(at.Z) or math.abs(at.X) > num(C.MaxCoord, 3000) or math.abs(at.Z) > num(C.MaxCoord, 3000) then
		return nil
	end
	local look = typeof(entry.Look) == "Vector3" and entry.Look or at
	return { X = at.X, Z = at.Z, LookX = look.X, LookZ = look.Z }
end

-- a HumanoidDescription of plain colours: the head / hands in Head, the arms the colour of the torso (sleeves), the legs trousers
local function describe(entry, vitals)
	local colors = entry.Colors or {}
	local desc = Instance.new("HumanoidDescription")
	local head = color(colors.Head, color((vitals.PotionMerchantColors or {}).Head, Color3.fromRGB(234, 184, 146)))
	local torso = color(colors.Torso, color((vitals.PotionMerchantColors or {}).Torso, Color3.fromRGB(46, 120, 92)))
	local legs = color(colors.Legs, color((vitals.PotionMerchantColors or {}).Legs, Color3.fromRGB(70, 55, 45)))
	desc.HeadColor = head
	desc.TorsoColor = torso
	desc.LeftArmColor, desc.RightArmColor = torso, torso
	desc.LeftLegColor, desc.RightLegColor = legs, legs
	return desc
end

-- the prompt of a talker / seller; false when the root is not a part of the model
local function ensurePrompt(npc, entry, C, vitals)
	local root = npc.PrimaryPart
	if not root or not root:IsA("BasePart") or not root:IsDescendantOf(npc) then return false end
	local name = entry.Merchant == true and vitals.PotionMerchantPrompt or "TalkPrompt"
	if entry.Story == nil and entry.Merchant ~= true then
		local old = root:FindFirstChild("TalkPrompt")
		if old and old:IsA("ProximityPrompt") then old.Enabled = false end
		return true
	end
	local prompt = root:FindFirstChild(name)
	if prompt and not prompt:IsA("ProximityPrompt") then prompt:Destroy(); prompt = nil end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
	end
	if entry.Merchant == true then
		prompt.ActionText, prompt.ObjectText = "Buy potions", entry.Label or vitals.PotionMerchantLabel or "Potion Seller"
		prompt.MaxActivationDistance = num(vitals.PotionMerchantDistance, 12)
	else
		prompt.ActionText, prompt.ObjectText = "Talk", entry.Label or entry.Story
		prompt.MaxActivationDistance = num(C.PromptDistance, 10)
		prompt:SetAttribute("StoryNpcId", entry.Story)
	end
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- the client's Keybinds retargets every prompt to the player's Interact key
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Enabled = entry.Enabled ~= false
	prompt:SetAttribute("Conversation", true) -- verified NPC interaction (the same marker as the potion seller)
	prompt.Parent = root
	return true
end

-- tags + attributes of an entry's model (idempotent)
local function mark(npc, entry, C)
	npc:SetAttribute("HHC_TownNpc", entry.Id)
	npc:SetAttribute("HHC_TownNpcLook", "DefaultNPC") -- the final look: remake P4
	CollectionService:AddTag(npc, "NPC")
	if entry.Story then
		CollectionService:AddTag(npc, Config.StoryQuests.NpcTag or "StoryNpc")
		npc:SetAttribute("NpcId", entry.Story)
	elseif entry.Merchant == true then
		CollectionService:AddTag(npc, "PotionMerchant")
		npc:SetAttribute("HHC_PotionMerchant", true)
	elseif entry.Folk then
		CollectionService:AddTag(npc, "TownFolk")
		npc:SetAttribute("FolkId", entry.Folk)
	end
end

-- puts a model on its spot (feet on the ground, facing its look point); false when there is no ground there
local function place(npc, entry, folder)
	local spot = TownNpcs.Spot(entry)
	if not spot then return false, "no spot" end
	local ground = TownNpcs.GroundY(spot.X, spot.Z, { folder })
	if not ground then return false, "no ground under the spot" end
	local pivot = npc:GetPivot()
	local bounds, size = npc:GetBoundingBox()
	local feet = pivot.Position.Y - (bounds.Position.Y - size.Y * 0.5)
	local pos = Vector3.new(spot.X, ground + feet, spot.Z)
	local look = Vector3.new(spot.LookX, pos.Y, spot.LookZ)
	if (look - pos).Magnitude > 0.5 then
		npc:PivotTo(CFrame.lookAt(pos, look))
	else
		npc:PivotTo(CFrame.new(pos))
	end
	npc:SetAttribute("HHC_TownNpcAt", string.format("%.1f,%.1f", spot.X, spot.Z))
	return true
end

local function signature(entry)
	local spot = TownNpcs.Spot(entry)
	return spot and string.format("%.1f,%.1f", spot.X, spot.Z) or nil
end

local function buildOne(entry, folder, C, vitals)
	local existing = folder:FindFirstChild(entry.Name)
	if existing and (not existing:IsA("Model") or existing:GetAttribute("HHC_TownNpc") ~= entry.Id) then
		Util.Warn(TAG, entry.Name .. " is occupied by unrelated content; skipped")
		return
	end
	if existing then
		-- repaired and moved when the spot changed; an entry turned off keeps its body but loses its prompt
		mark(existing, entry, C)
		ensurePrompt(existing, entry, C, vitals)
		local sig = signature(entry)
		if entry.Enabled ~= false and sig and existing:GetAttribute("HHC_TownNpcAt") ~= sig then
			local ok, why = place(existing, entry, folder)
			if not ok then Util.Warn(TAG, entry.Name .. " not moved: " .. tostring(why)) end
		end
		return
	end
	if entry.Enabled == false then return end
	local spot = TownNpcs.Spot(entry)
	local ground = spot and TownNpcs.GroundY(spot.X, spot.Z, { folder })
	if not ground then
		Util.Warn(TAG, entry.Name .. " skipped: no ground under its spot (the map is not built here)")
		return
	end
	local made, npc = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(describe(entry, vitals), Enum.HumanoidRigType.R15)
	end)
	if not made or not npc then
		Util.Warn(TAG, entry.Name .. " body failed: " .. tostring(npc))
		return
	end
	if folder:FindFirstChild(entry.Name) then npc:Destroy(); return end -- built meanwhile
	local prepared, why = pcall(function()
		npc.Name = entry.Name
		for _, child in npc:GetDescendants() do
			if child:IsA("LuaSourceContainer") then
				child:Destroy()
			elseif child:IsA("BasePart") then
				child.Anchored = true
				child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
			end
		end
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local root = npc:FindFirstChild("HumanoidRootPart")
		assert(humanoid and root and root:IsA("BasePart"), "default NPC has no root/humanoid")
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		npc.PrimaryPart = root
		local placed, reason = place(npc, entry, folder)
		assert(placed, reason)
		mark(npc, entry, C)
		assert(ensurePrompt(npc, entry, C, vitals), "default NPC root is invalid")
		npc.Parent = folder
	end)
	if not prepared then
		npc:Destroy()
		Util.Warn(TAG, entry.Name .. " preparation failed: " .. tostring(why))
	end
end

-- the entries that are well formed (a name and an id, no duplicates)
function TownNpcs.Entries()
	local out, seenId, seenName = {}, {}, {}
	local C = Config.TownNpcs
	for _, entry in type(C) == "table" and type(C.List) == "table" and C.List or {} do
		if type(entry) == "table" and type(entry.Id) == "string" and type(entry.Name) == "string" and entry.Name ~= ""
			and not seenId[entry.Id] and not seenName[entry.Name] then
			seenId[entry.Id], seenName[entry.Name] = true, true
			table.insert(out, entry)
		end
	end
	return out
end

-- MapBuilder.Build: ctx.pieces counts the bodies still to be made; folder = Map.NPCs. Returns the number queued.
function TownNpcs.Ensure(ctx, folder)
	local C = Config.TownNpcs
	if type(C) ~= "table" then return 0 end
	local vitals = Config.Vitals
	local queue = {}
	for _, entry in TownNpcs.Entries() do
		local existing = folder:FindFirstChild(entry.Name)
		if C.Enabled ~= true then
			-- switched off: the prompts of our own bodies go quiet (the bodies stay)
			if existing and existing:IsA("Model") and existing:GetAttribute("HHC_TownNpc") == entry.Id and existing.PrimaryPart then
				for _, d in existing.PrimaryPart:GetChildren() do
					if d:IsA("ProximityPrompt") then d.Enabled = false end
				end
			end
		else
			table.insert(queue, entry)
			if not existing and entry.Enabled ~= false then ctx.pieces += 1 end
		end
	end
	if #queue == 0 then return 0 end
	task.spawn(function()
		for _, entry in queue do
			local ok, err = pcall(buildOne, entry, folder, C, vitals)
			if not ok then Util.Warn(TAG, tostring(entry.Name) .. ": " .. tostring(err)) end
		end
	end)
	return #queue
end

return TownNpcs
