-- NameTagPrefs.luau (게임성 개발 1, 2026-10-14; gameplay_plan 2-C #9, 최종 검수 10/14): the Settings row "Other players'
-- name tags" (Config.Settings Tags = "All" | "Near" | "Off") on this client. Until now the value was saved but nothing
-- read it. The tags are the server's (CharacterVisuals: a BillboardGui "Nametag" on every character's Head, rebuilt on
-- many attribute changes; my own one has PlayerToHideFrom = me). Here, only on this screen and only for OTHER players'
-- tags: All = shown up to Config.Visuals.NametagMaxDistance (the server's own value), Near = shown up to
-- NametagNearDistance, Off = hidden. A tag the server makes later (a rebuild, a new player) gets it at once; a Settings
-- change applies to every tag. Presentation only (the server never reads it).
-- API: NameTagPrefs.Init(C), NameTagPrefs.Start(), NameTagPrefs.Plan(mode) -> { Enabled, MaxDistance } (pure),
-- NameTagPrefs.Apply(bb) -> bool (true when it changed a tag), NameTagPrefs.ApplyAll() -> count.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local NameTagPrefs = {}
local C = nil
local TAG = "NameTagPrefs"
local L = { Name = "Nametag", Far = 120, Near = 40 }
-- 최종 검수 10/14 FIX 1: Tags is a STRONG table (with weak keys a tag already on screen could drop out, and the server
-- fixes a tag in place without making a new one, so a later Settings change missed it); gone tags are dropped in ApplyAll
local S = { Tags = {}, Started = false }

local function visuals() return type(Config.Visuals) == "table" and Config.Visuals or {} end

local function mode()
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return "All" end
	local ok, v = pcall(st.Get, "Tags")
	return (ok and (v == "All" or v == "Near" or v == "Off")) and v or "All"
end

-- (pure) what a mode does to another player's tag
function NameTagPrefs.Plan(m)
	local V = visuals()
	local far = tonumber(V.NametagMaxDistance) or L.Far
	local near = math.min(far, tonumber(V.NametagNearDistance) or L.Near)
	if m == "Off" then return { Enabled = false, MaxDistance = far } end
	if m == "Near" then return { Enabled = true, MaxDistance = near } end
	return { Enabled = true, MaxDistance = far }
end

-- one tag: someone else's server Nametag gets my mode; mine (hidden from me by the server) and others are left alone
function NameTagPrefs.Apply(bb)
	if typeof(bb) ~= "Instance" or not bb:IsA("BillboardGui") or bb.Name ~= L.Name then return false end
	if LocalPlayer and bb.PlayerToHideFrom == LocalPlayer then return false end
	S.Tags[bb] = true
	local plan = NameTagPrefs.Plan(mode())
	local changed = false
	if bb.Enabled ~= plan.Enabled then
		bb.Enabled = plan.Enabled
		changed = true
	end
	if bb.MaxDistance ~= plan.MaxDistance then
		bb.MaxDistance = plan.MaxDistance
		changed = true
	end
	return changed
end

-- every tag again (a Settings change): each other player's Head "Nametag" is looked up afresh too (one missing from the
-- table is found); gone tags are dropped
function NameTagPrefs.ApplyAll()
	for _, p in Players:GetPlayers() do
		local char = p ~= LocalPlayer and p.Character
		local head = char and char:FindFirstChild("Head")
		local bb = head and head:FindFirstChild(L.Name)
		if bb and bb:IsA("BillboardGui") then S.Tags[bb] = true end
	end
	local n = 0
	for bb in S.Tags do
		if bb.Parent then
			if NameTagPrefs.Apply(bb) then n += 1 end
		else
			S.Tags[bb] = nil
		end
	end
	return n
end

function NameTagPrefs.Init(registry)
	C = registry
end

function NameTagPrefs.Start()
	if S.Started then return end
	S.Started = true
	local function consider(d)
		if d.Name == L.Name and d:IsA("BillboardGui") then
			local ok, err = pcall(NameTagPrefs.Apply, d)
			if not ok then Util.Warn(TAG, "apply: " .. tostring(err)) end
		end
	end
	for _, d in workspace:GetDescendants() do consider(d) end
	workspace.DescendantAdded:Connect(consider)
	local st = C and C.Settings
	if type(st) == "table" and type(st.Changed) == "table" and type(st.Changed.Connect) == "function" then
		st.Changed:Connect(function()
			local ok, err = pcall(NameTagPrefs.ApplyAll)
			if not ok then Util.Warn(TAG, "apply all: " .. tostring(err)) end
		end)
	end
end

NameTagPrefs._T = { S = S } -- tools/test_settings_apply.py

return NameTagPrefs
