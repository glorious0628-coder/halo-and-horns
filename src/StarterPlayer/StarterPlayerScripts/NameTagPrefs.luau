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
local L = { Name = "Nametag", Far = 120, Near = 40,
	-- 2-C #9 (A23-77 milestone 28 "이름표 테두리", Config.Attendance.Milestones Border): the approved ribbon of that border
	-- (Config.UIArt "Ribbon" .. Border) right of the name, its height a share of the name's drawn height; Sweep s between
	-- passes over every tag (a new tag, AttendDays, the name re-scaled)
	Border = { Art = "Ribbon", Height = 0.9, Gap = 3, Sweep = 1, Child = "AttendBorder" } }
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

-- (pure) the attendance border a player has: the highest Config.Attendance.Milestones row with a Border whose Days <=
-- days collected (AttendDays) -> its Border id, or nil
function NameTagPrefs.BorderOf(days)
	days = math.floor(tonumber(days) or 0)
	local att = type(Config.Attendance) == "table" and Config.Attendance or {}
	local best, bestDays = nil, -1
	for _, m in type(att.Milestones) == "table" and att.Milestones or {} do
		local d = type(m) == "table" and tonumber(m.Days) or nil
		if d and type(m.Border) == "string" and d <= days and d > bestDays then best, bestDays = m.Border, d end
	end
	return best
end

-- one tag's ribbon: added / moved / removed by its owner's AttendDays (any player's tag, mine is hidden from me anyway)
function NameTagPrefs.FitBorder(bb, player)
	if typeof(bb) ~= "Instance" or not bb:IsA("BillboardGui") then return false end
	local line = bb:FindFirstChild("Line1")
	if not (line and line:IsA("TextLabel")) then return false end
	local B = L.Border
	local border = typeof(player) == "Instance" and NameTagPrefs.BorderOf(player:GetAttribute("AttendDays")) or nil
	local img = line:FindFirstChild(B.Child)
	local kit = C and C.UIKit
	local id = border and type(kit) == "table" and type(kit.ArtId) == "function" and kit.ArtId(B.Art .. border) or nil
	if not id then
		if img then img:Destroy() end
		return false
	end
	if not (img and img:IsA("ImageLabel")) then
		if img then img:Destroy() end
		img = Instance.new("ImageLabel")
		img.Name = B.Child
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0, 0.5)
		img.Parent = line
	end
	if img.Image ~= id then img.Image = id end
	local tb = line.TextBounds
	local h = math.max(8, math.floor((tb.Y > 0 and tb.Y or 20) * B.Height + 0.5))
	local size = UDim2.fromOffset(h, h)
	local pos = UDim2.new(0.5, math.floor(tb.X / 2 + B.Gap + 0.5), 0.5, 0)
	if img.Size ~= size then img.Size = size end
	if img.Position ~= pos then img.Position = pos end
	return true
end

-- every player's tag once (the sweep)
function NameTagPrefs.FitBorders()
	local n = 0
	for _, p in Players:GetPlayers() do
		local head = p.Character and p.Character:FindFirstChild("Head")
		local bb = head and head:FindFirstChild(L.Name)
		if bb and NameTagPrefs.FitBorder(bb, p) then n += 1 end
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
	pcall(function() -- 2-C #9: the 28-day ribbons (a slow sweep: writes only on a change)
		task.spawn(function()
			while true do
				local ok, err = pcall(NameTagPrefs.FitBorders)
				if not ok then Util.Warn(TAG, "borders: " .. tostring(err)) end
				task.wait(L.Border.Sweep)
			end
		end)
	end)
	local st = C and C.Settings
	if type(st) == "table" and type(st.Changed) == "table" and type(st.Changed.Connect) == "function" then
		st.Changed:Connect(function()
			local ok, err = pcall(NameTagPrefs.ApplyAll)
			if not ok then Util.Warn(TAG, "apply all: " .. tostring(err)) end
		end)
	end
end

NameTagPrefs._T = { S = S, L = L } -- tools/test_settings_apply.py, tools/test_small_ui.py

return NameTagPrefs
