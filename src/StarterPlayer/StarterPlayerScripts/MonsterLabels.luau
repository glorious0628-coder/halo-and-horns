-- MonsterLabels.luau : which monster name / HP bars this client shows (review of devlog 12, 2026-10-06: ghost packs and
-- slime crowds stacked their name tags into each other and over the quest lines). MonsterService builds one
-- "MonsterBar" BillboardGui per monster (name + Bar/Fill); the server never hides them, this client does:
--   * the name tag shows for the nearest MAX_NAMES monsters within NAME_RANGE studs of me, for any monster hurt in the
--     last HURT_SECONDS (the one I am fighting), and for event bosses (the kings) while in their bar range;
--   * the HP bar under it shows only while the monster was hurt in the last HURT_SECONDS (bosses: always).
-- Hurt = its Fill bar got shorter (server bar updates replicate). Local only: Enabled / Visible never replicate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MonsterLabels = {}
local LocalPlayer = Players.LocalPlayer

local T = { Tick = 0.2, NameRange = 30, MaxNames = 5, HurtSeconds = 4 }
local S = { Started = false, Fill = {}, HurtAt = {} } -- [BillboardGui] = last Fill scale / os.clock() of the last drop

local function myPos()
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root then return root.Position end
	local cam = workspace.CurrentCamera
	return cam and cam.Focus.Position or nil
end

local function isBoss(model)
	local kind = model:GetAttribute("MonsterKind") or model.Name
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return type(def) == "table" and def.Boss == true
end

local function tick()
	local folder = workspace:FindFirstChild("Monsters")
	local me = myPos()
	if not folder or not me then return end
	local now = os.clock()
	local rows, seen = {}, {}
	for _, model in folder:GetChildren() do
		local bb = model:FindFirstChild("MonsterBar", true)
		local root = bb and bb.Parent
		if bb and bb:IsA("BillboardGui") and root and root:IsA("BasePart") then
			seen[bb] = true
			local back = bb:FindFirstChild("Bar")
			local fill = back and back:FindFirstChild("Fill")
			local scale = fill and fill.Size.X.Scale or 1
			local last = S.Fill[bb]
			if last and scale < last - 1e-4 then S.HurtAt[bb] = now end
			S.Fill[bb] = scale
			local d = (root.Position - me).Magnitude
			local hurt = S.HurtAt[bb] ~= nil and now - S.HurtAt[bb] <= T.HurtSeconds
			table.insert(rows, { BB = bb, Back = back, D = d, Hurt = hurt, Boss = isBoss(model) })
		end
	end
	table.sort(rows, function(a, b) return a.D < b.D end)
	local names = 0
	for _, r in rows do
		local near = r.D <= T.NameRange and names < T.MaxNames
		if near then names += 1 end
		local show = near or r.Hurt or r.Boss
		if r.BB.Enabled ~= show then r.BB.Enabled = show end
		if r.Back then
			local bar = r.Hurt or r.Boss
			if r.Back.Visible ~= bar then r.Back.Visible = bar end
		end
	end
	-- forget bars of monsters that are gone
	for bb in S.Fill do
		if not seen[bb] then
			S.Fill[bb] = nil
			S.HurtAt[bb] = nil
		end
	end
end

function MonsterLabels.Init(_c) end

function MonsterLabels.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then warn("[MonsterLabels] " .. tostring(err)) end
			task.wait(T.Tick)
		end
	end)
	print("[MonsterLabels] started")
end

return MonsterLabels
