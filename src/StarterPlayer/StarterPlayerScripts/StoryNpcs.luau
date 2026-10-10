-- StoryNpcs.luau (게임성 개발 1; 빛 마을 점검 #22 / #25 / #30, server = 게임성 개발 3's TownNpcs,
-- docs/design/town_npcs_server_2026-10-10.md): the client side of the town's story NPC bodies (Bright, Sir Gleam: tag
-- Config.StoryQuests.NpcTag, attribute NpcId, a "Talk" ProximityPrompt with attribute StoryNpcId that the server opens).
--   A small gold "!" floats over an NPC while one of my quest rows (HUD.QuestEntries: the quest window's More rows too)
--   is a talk step through her (Story.Npc - the server sends it only while the step is not waiting for [Claim]); her
--   Talk prompt shows only then (Enabled set on this client only), so a press never lands on "nothing to say".
--   The townsfolk (tag TownFolk) get nothing here. The marker / the row tap that lead to her are QuestTarget / HUD.
-- No new art: a text "!" in the UIKit font with a dark outline (round, never rays).
-- Public API: StoryNpcs.Init(C), StoryNpcs.Start(), StoryNpcs.Called(entries) -> { [npcId] = true } (pure),
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

-- the model's one "!" (made once; extra copies from older passes are removed)
function StoryNpcs.Mark(model)
	local bb = nil
	for _, ch in model:GetChildren() do
		if ch.Name == "StoryNpcMark" and ch:IsA("BillboardGui") then
			if bb then ch:Destroy() else bb = ch end
		end
	end
	if bb then return bb end
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		head = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
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
		game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt) StoryNpcs.OnPrompt(prompt) end)
	end)
	-- a quest list change shows / hides at once (the pass above catches NPCs that arrive later)
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.QuestsChanged) == "table" and type(hud.QuestsChanged.Connect) == "function" then
		hud.QuestsChanged:Connect(function() pcall(StoryNpcs.Refresh) end)
	end
end

return StoryNpcs
