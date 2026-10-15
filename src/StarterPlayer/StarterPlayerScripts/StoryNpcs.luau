-- StoryNpcs.luau (게임성 개발 1; 빛 마을 점검 #22 / #25 / #30, server = 게임성 개발 3's TownNpcs,
-- docs/design/town_npcs_server_2026-10-10.md): the client side of the town's story NPC bodies (Bright, Sir Gleam: tag
-- Config.StoryQuests.NpcTag, attribute NpcId, a "Talk" ProximityPrompt with attribute StoryNpcId that the server opens).
--   A small gold "!" floats over an NPC while one of my quest rows (HUD.QuestEntries: the quest window's More rows too)
--   is a talk step through her (Story.Npc - the server sends it only while the step is not waiting for [Claim]); her
--   Talk prompt shows only then (Enabled set on this client only), so a press never lands on "nothing to say".
--   The townsfolk (tag TownFolk) get nothing here. The marker / the row tap that lead to her are QuestTarget / HUD.
-- No new art: a text "!" in the UIKit font with a dark outline (round, never rays).
-- A23-199: an NPC with a request (attribute StoryOffers) gets the "!" too; a Pickup step's thing lies at its spot.
-- Public API: StoryNpcs.Init(C), StoryNpcs.Start(), StoryNpcs.Called(entries) -> { [npcId] = true } (pure),
-- StoryNpcs.Offers(text) / StoryNpcs.Pickups(entries, faction) (pure), StoryNpcs.DrawPickups(list), StoryNpcs.OnPickup(prompt),
-- StoryNpcs.OnPrompt(prompt) -> bool (a Talk prompt press: Panels.ExpectStory), StoryNpcs.Refresh() (one pass now),
-- StoryNpcs.Mark(model) -> its one "!" BillboardGui (made once, reused).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local StoryNpcs = {}
local C = nil
local TAG = "StoryNpcs"

local T = {
	Every = 0.5, -- s between passes (quest rows and NPCs change rarely)
	MarkText = "!",
	MarkSize = 40, -- px (the billboard is MarkSize x MarkSize)
	MarkLift = 2.4, -- studs over the head
	MarkDistance = 90, -- studs: the "!" shows within this distance
	Gold = Color3.fromRGB(255, 214, 72),
}
-- 검수 10/10 (main Play: seven "!" stacked under Bright): the mark is found ON the model (its child StoryNpcMark), never
-- in a weak table - a weak-keyed Instance entry is dropped once Lua holds no reference, so every pass made a new one
local S = { Started = false }

-- the NPC ids my rows talk through (pure: entries = HUD quest rows)
function StoryNpcs.Called(entries)
	local out = {}
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		if type(st) == "table" and type(st.Npc) == "string" and st.Npc ~= "" then out[st.Npc] = true end
	end
	return out
end

-- A23-199 (개발 2 quest_offer_server_2026-10-15): the NPCs that have a request for me (attribute StoryOffers = their ids,
-- comma separated, "" = none) -> { [npcId] = true } (pure)
function StoryNpcs.Offers(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for id in string.gmatch(text, "[^,%s]+") do out[id] = true end
	return out
end

-- A23-199 (pure): my rows' open Pickup steps -> { { Id, Spot, Pos, Radius } } (the step of each Story row, my side's
-- override first; the spot from Config.StoryQuests.Landmarks)
function StoryNpcs.Pickups(entries, faction)
	local sq = type(Config.StoryQuests) == "table" and Config.StoryQuests or {}
	local defs = type(sq.Defs) == "table" and sq.Defs or {}
	local marks = type(sq.Landmarks) == "table" and sq.Landmarks or {}
	local out, seen = {}, {}
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		local def = type(st) == "table" and type(st.Id) == "string" and defs[st.Id] or nil
		local step = type(def) == "table" and type(def.Steps) == "table" and def.Steps[tonumber(st.St) or 0] or nil
		if type(step) == "table" then
			local over = type(faction) == "string" and step[faction] or nil
			local obj = (type(over) == "table" and type(over.Obj) == "table" and over.Obj) or step.Obj
			if type(obj) == "table" and obj.Type == "Pickup" and type(obj.Spot) == "string" and typeof(marks[obj.Spot]) == "Vector3"
				and not seen[st.Id] then
				seen[st.Id] = true
				table.insert(out, { Id = st.Id, Spot = obj.Spot, Pos = marks[obj.Spot], Radius = tonumber(obj.Radius) or 8 })
			end
		end
	end
	return out
end

-- the model's one "!" (made once; extra copies from older passes are removed)
function StoryNpcs.Mark(model)
	local bb = nil
	for _, ch in model:GetChildren() do
		if ch.Name == "StoryNpcMark" and ch:IsA("BillboardGui") then
			if bb then ch:Destroy() else bb = ch end
		end
	end
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		head = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	if bb then
		-- 검수 10/10 (API review ②): the body may be rebuilt (a new head): the "!" follows the head it has now
		if head and bb.Adornee ~= head then bb.Adornee = head end
		return bb
	end
	if not head then return nil end
	bb = Instance.new("BillboardGui")
	bb.Name = "StoryNpcMark"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(T.MarkSize, T.MarkSize)
	bb.StudsOffsetWorldSpace = Vector3.new(0, T.MarkLift, 0)
	bb.MaxDistance = T.MarkDistance
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Mark"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	local ui = C and C.UIKit
	local theme = type(ui) == "table" and ui.Theme or nil
	label.Font = (type(theme) == "table" and typeof(theme.TitleFont) == "EnumItem" and theme.TitleFont)
		or (type(theme) == "table" and typeof(theme.Font) == "EnumItem" and theme.Font) or Enum.Font.GothamBlack
	label.Text = T.MarkText
	label.TextScaled = true
	label.TextColor3 = T.Gold
	label.TextStrokeTransparency = 0.2
	label.Parent = bb
	bb.Parent = model
	return bb
end

-- one pass: the "!" and the Talk prompt of each story NPC follow my rows
function StoryNpcs.Refresh()
	local hud = C and C.HUD
	local entries = nil
	if type(hud) == "table" and type(hud.QuestEntries) == "function" then
		local ok, list = pcall(hud.QuestEntries)
		if ok then entries = list end
	end
	local called = StoryNpcs.Called(entries)
	-- A23-193 (main Play 10/14: Sir Gleam's Talk prompt stayed off): the teacher of a ready skill is called too (server
	-- attributes SkillLearnReady > SkillSlots, SkillTeacher = the NpcId), so the "!" shows and the Talk press reaches
	-- SkillService.TryLearn
	local me = game:GetService("Players").LocalPlayer
	if me then
		local teacher = me:GetAttribute("SkillTeacher")
		local ready, slots = tonumber(me:GetAttribute("SkillLearnReady")) or 0, tonumber(me:GetAttribute("SkillSlots")) or 0
		if type(teacher) == "string" and teacher ~= "" and ready > slots then called[teacher] = true end
		-- A23-199: an NPC with a request for me shows the "!" and her Talk prompt (the press opens the Offer window)
		for id in StoryNpcs.Offers(me:GetAttribute("StoryOffers")) do called[id] = true end
		pcall(StoryNpcs.DrawPickups, StoryNpcs.Pickups(entries, me:GetAttribute("Faction")))
	end
	local tag = type(Config.StoryQuests) == "table" and Config.StoryQuests.NpcTag or "StoryNpc"
	local ok, list = pcall(function() return game:GetService("CollectionService"):GetTagged(tag) end)
	if not ok or type(list) ~= "table" then return end
	for _, model in list do
		if typeof(model) == "Instance" and model:IsDescendantOf(workspace) then
			local id = model:GetAttribute("NpcId")
			local on = type(id) == "string" and called[id] == true
			local bb = StoryNpcs.Mark(model)
			if bb then bb.Enabled = on end
			for _, d in model:GetDescendants() do
				if d:IsA("ProximityPrompt") and d:GetAttribute("StoryNpcId") ~= nil and d.Enabled ~= on then d.Enabled = on end
			end
		end
	end
end

-- A23-199: the things to pick up of my open Pickup steps, only while that step is open: a small box on the ground at
-- the spot, a soft light and round sparkles (no rays), a "Pick up" prompt -> StoryAction(Id, "Pickup"); a step that
-- closed takes its box away. Client-only parts in workspace.StoryPickups (no collision, no query)
T.Pickup = { Folder = "StoryPickups", Size = Vector3.new(1.4, 0.9, 1.1), Lift = 0.45, Range = 9, Hold = 0,
	Color = Color3.fromRGB(196, 140, 84), Lid = Color3.fromRGB(235, 95, 85), Light = Color3.fromRGB(255, 225, 150) }

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local folder = workspace:FindFirstChild(T.Pickup.Folder)
	if folder then table.insert(ignore, folder) end
	local me = game:GetService("Players").LocalPlayer
	if me and me.Character then table.insert(ignore, me.Character) end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 200, pos.Z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or pos.Y
end

local function makePickup(p)
	local P = T.Pickup
	local m = Instance.new("Model")
	m.Name = "Pickup_" .. p.Id
	m:SetAttribute("StoryId", p.Id)
	local y = groundAt(p.Pos) + P.Lift
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size, box.Color, box.Material = P.Size, P.Color, Enum.Material.SmoothPlastic
	box.CFrame = CFrame.new(p.Pos.X, y, p.Pos.Z)
	box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false, false
	box.Parent = m
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(P.Size.X + 0.08, 0.22, P.Size.Z + 0.08)
	lid.Color, lid.Material = P.Lid, Enum.Material.SmoothPlastic
	lid.CFrame = box.CFrame * CFrame.new(0, P.Size.Y / 2 + 0.11, 0)
	lid.Anchored, lid.CanCollide, lid.CanQuery, lid.CanTouch, lid.CastShadow = true, false, false, false, false
	lid.Parent = m
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = P.Light, 8, 1.2
	light.Parent = box
	local spark = Instance.new("ParticleEmitter")
	spark.Name = "Sparkle"
	spark.Color = ColorSequence.new(P.Light)
	spark.LightEmission, spark.Rate = 0.8, 6
	spark.Lifetime = NumberRange.new(0.6, 1.1)
	spark.Speed = NumberRange.new(0.5, 1.5)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	spark.Parent = lid
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	local words = type(Config.StoryQuests.Text) == "table" and Config.StoryQuests.Text.Pickup or "Pick up"
	prompt.ActionText, prompt.ObjectText = words, ""
	prompt.MaxActivationDistance = math.min(P.Range, p.Radius + 1)
	prompt.HoldDuration = P.Hold
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("StoryPickup", p.Id)
	prompt.Parent = box
	m.PrimaryPart = box
	return m
end

-- the boxes follow the open Pickup steps (made once per step, removed when it closes)
function StoryNpcs.DrawPickups(list)
	local folder = workspace:FindFirstChild(T.Pickup.Folder)
	if #list == 0 and not folder then return 0 end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = T.Pickup.Folder
		folder.Parent = workspace
	end
	local want = {}
	for _, p in list do want[p.Id] = p end
	for _, m in folder:GetChildren() do
		local id = m:GetAttribute("StoryId")
		if not want[id] then m:Destroy() else want[id] = nil end
	end
	for _, p in want do makePickup(p).Parent = folder end
	return #folder:GetChildren()
end

-- a press on a box's prompt asks the server (it checks the step and the distance)
function StoryNpcs.OnPickup(prompt)
	local id = typeof(prompt) == "Instance" and prompt:GetAttribute("StoryPickup") or nil
	if type(id) ~= "string" then return false end
	local ok, remote = pcall(function() return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):FindFirstChild("StoryAction") end)
	if ok and remote then remote:FireServer(id, "Pickup") end
	return true
end

-- 검수 10/10 (NPC review): a press on a story NPC's Talk prompt asked for this page, so the server's reply opens even
-- while Panels would make an auto-opened page wait (STORY.Busy) - like a tap on the quest row (Panels.ExpectStory)
function StoryNpcs.OnPrompt(prompt)
	local id = typeof(prompt) == "Instance" and prompt:GetAttribute("StoryNpcId") or nil
	if id == nil then return false end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.ExpectStory) ~= "function" then return false end
	pcall(panels.ExpectStory, tostring(id))
	return true
end

function StoryNpcs.Init(registry)
	C = registry
end

function StoryNpcs.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(StoryNpcs.Refresh)
			if not ok then Util.Warn(TAG, "refresh failed: " .. tostring(err)) end
			task.wait(T.Every)
		end
	end)
	pcall(function()
		game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
			if not StoryNpcs.OnPickup(prompt) then StoryNpcs.OnPrompt(prompt) end
		end)
	end)
	-- a quest list change shows / hides at once (the pass above catches NPCs that arrive later)
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.QuestsChanged) == "table" and type(hud.QuestsChanged.Connect) == "function" then
		hud.QuestsChanged:Connect(function() pcall(StoryNpcs.Refresh) end)
	end
end

return StoryNpcs
