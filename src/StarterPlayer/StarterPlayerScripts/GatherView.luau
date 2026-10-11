-- GatherView.luau (게임성 개발 4, ② 채집 G 꾹 화면; SPEC A23-119 · A23-127 · A23-133 · A23-130 · A23-78, contract: 개발 3
-- origin/dev3-gather docs/design/gather_server_2026-10-11.md §7, rules docs/design/gathering_2026-10-06.md §3).
-- The nodes are the server's (workspace.Map.GatherNodes: Models with GatherId / GatherKind and a ProximityPrompt
-- "GatherPrompt" with HoldDuration = the node's time, ActionText / ObjectText "" and the attributes ActionKey / ObjectKey
-- naming the words). Roblox's own prompt draws the hold ring; Keybinds puts the Interact key (G) on it. Here, for me only:
--   * words: the prompt's ActionText / ObjectText from its keys ("Pick" / "Mine" + the item's name; Korean when I read
--     Korean, again when my language changes)
--   * rest: a node that rests for me (GatherState.Ready[GatherId] still in the future) has its prompt off, its parts faded
--     (LocalTransparencyModifier) and its sparkles / lights off; it comes back when that time passes (every Poll s)
-- Nothing else (A23-130 less text: no first-time hint line; the hold ring says it): the loot popup is Fx "Loot", the
-- Shard Bloom is the choice card, the daily cap / PvP notices are the server's NotifyKey lines. No remote is sent.
-- s->c "GatherState" { Ready = { [GatherId] = server time (workspace:GetServerTimeNow) it is ready again }, N, Cap }.
-- Public API: GatherView.Init(C), GatherView.Start(), GatherView.OnState(payload), GatherView.Refresh(), GatherView.Tick(),
-- pure: GatherView.Words(actionKey, objectKey, lang) -> action, object, GatherView.Resting(ready, id, now) -> bool
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local GatherView = {}
local C = nil
local TAG = "GatherView"
local LocalPlayer = Players.LocalPlayer

local G = {
	Map = "Map", Folder = "GatherNodes", Prompt = "GatherPrompt", Remote = "GatherState",
	IdAttr = "GatherId", ActionKey = "ActionKey", ObjectKey = "ObjectKey",
	Poll = 0.5, -- s between rest checks
	Fade = 0.6, -- LocalTransparencyModifier of a resting node's parts (still seen, clearly 'not now')
	MaxIds = 512, -- GatherState entries kept (the server sends one per node at most)
	Wait = 60, -- s to wait for the map / the remote
}
-- Ready: [GatherId] = server time; Resting: [Model] = true while faded; Lit: [ParticleEmitter | Light] = its own Enabled
local S = { Ready = {}, N = 0, Cap = 0, Folder = nil, Resting = {}, Lit = setmetatable({}, { __mode = "k" }), Started = false }

local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function lang()
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.Lang) == "function" then
		local ok, l = pcall(ui.Lang)
		if ok and (l == "ko" or l == "en") then return l end
	end
	return L10n.LangOf(LocalPlayer)
end

local function now()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or Util.Now()
end

---------------------------------------------------------------------------------------------------- pure
-- the prompt's two words from its keys (a missing / empty / unknown key = no word)
function GatherView.Words(actionKey, objectKey, language)
	local function word(key)
		if type(key) ~= "string" or key == "" then return "" end
		local ok, s = pcall(L10n.T, key, nil, language)
		if not ok or type(s) ~= "string" or s == key then return "" end -- an unknown key comes back as itself
		return s
	end
	return word(actionKey), word(objectKey)
end

function GatherView.Resting(ready, id, t)
	local at = type(ready) == "table" and type(id) == "string" and ready[id] or nil
	return type(at) == "number" and at > t
end

---------------------------------------------------------------------------------------------------- nodes
local function promptOf(model)
	local p = model:FindFirstChild(G.Prompt, true)
	return (p and p:IsA("ProximityPrompt")) and p or nil
end

local function setWords(model)
	local p = promptOf(model)
	if not p then return end
	local action, object = GatherView.Words(p:GetAttribute(G.ActionKey), p:GetAttribute(G.ObjectKey), lang())
	if action ~= "" and p.ActionText ~= action then p.ActionText = action end
	if object ~= "" and p.ObjectText ~= object then p.ObjectText = object end
end

-- fade a node for me (or bring it back): its prompt, parts, sparkles and lights
local function setRest(model, resting)
	if (S.Resting[model] == true) == resting then return end
	S.Resting[model] = resting or nil
	local p = promptOf(model)
	if p then p.Enabled = not resting end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = resting and G.Fade or 0
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			if resting then
				if S.Lit[d] == nil then S.Lit[d] = d.Enabled end
				d.Enabled = false
			elseif S.Lit[d] ~= nil then
				d.Enabled = S.Lit[d]
				S.Lit[d] = nil
			end
		end
	end
end

local function applyNode(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end
	local id = model:GetAttribute(G.IdAttr)
	if type(id) ~= "string" then return end
	setWords(model)
	setRest(model, GatherView.Resting(S.Ready, id, now()))
end

-- every node again (a new GatherState, the language changed, the poll)
function GatherView.Refresh()
	local folder = S.Folder
	if not (folder and folder.Parent) then return end
	for _, m in folder:GetChildren() do
		local ok, err = pcall(applyNode, m)
		if not ok then Util.Warn(TAG, "node: " .. tostring(err)) end
	end
	for m in table.clone(S.Resting) do
		if not m.Parent then S.Resting[m] = nil end -- streamed out / removed
	end
end

-- s->c GatherState: the nodes resting for me (validated: string ids, finite times, at most MaxIds)
function GatherView.OnState(payload)
	if type(payload) ~= "table" then return end
	local ready, n = {}, 0
	if type(payload.Ready) == "table" then
		for id, at in payload.Ready do
			if n >= G.MaxIds then break end
			local t = num(at, nil)
			if type(id) == "string" and #id <= 64 and t then
				ready[id] = t
				n += 1
			end
		end
	end
	S.Ready = ready
	S.N = math.max(0, math.floor(num(payload.N, 0)))
	S.Cap = math.max(0, math.floor(num(payload.Cap, 0)))
	GatherView.Refresh()
end

local function watchFolder(folder)
	if S.Folder == folder then return end
	S.Folder = folder
	folder.ChildAdded:Connect(function(m)
		task.defer(function() -- its prompt / attributes arrive with it
			local ok, err = pcall(applyNode, m)
			if not ok then Util.Warn(TAG, "node: " .. tostring(err)) end
		end)
	end)
	GatherView.Refresh()
end

local function findFolder()
	local map = workspace:WaitForChild(G.Map, G.Wait)
	if not map then return end
	local folder = map:FindFirstChild(G.Folder)
	if folder then
		watchFolder(folder)
	end
	map.ChildAdded:Connect(function(ch)
		if ch.Name == G.Folder then watchFolder(ch) end
	end)
end

local function bind()
	local function hook(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(GatherView.OnState, payload)
			if not ok then Util.Warn(TAG, "state: " .. tostring(err)) end
		end)
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(G.Remote)
	if remote and remote:IsA("RemoteEvent") then
		hook(remote)
		return
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("Remotes", G.Wait)
		local r = f and f:WaitForChild(G.Remote, G.Wait)
		if r and r:IsA("RemoteEvent") then hook(r) end -- no remote = gathering is off on this server (no warning)
	end)
end

function GatherView.Init(registry)
	C = registry
	bind() -- before any Start, so the first GatherState is never missed
end

function GatherView.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(findFolder)
	local ui = C and C.UIKit
	if type(ui) == "table" and ui.LangChanged and type(ui.LangChanged.Connect) == "function" then
		ui.LangChanged:Connect(function() GatherView.Refresh() end)
	end
	task.spawn(function()
		while true do
			task.wait(G.Poll)
			GatherView.Tick()
		end
	end)
end

-- the poll: only what rests can change by itself - a node whose time passed comes back
function GatherView.Tick()
	local t = now()
	for m in table.clone(S.Resting) do
		local id = m.Parent and m:GetAttribute(G.IdAttr)
		if not m.Parent then
			S.Resting[m] = nil
		elseif not GatherView.Resting(S.Ready, id, t) then
			local ok, err = pcall(setRest, m, false)
			if not ok then Util.Warn(TAG, "rest: " .. tostring(err)) end
		end
	end
end

-- offline tests
GatherView._T = { G = G, S = S }

return GatherView
