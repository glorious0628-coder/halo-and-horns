-- MonsterLabels.luau : which monster name / HP bars this client shows (review of devlog 12, 2026-10-06: ghost packs and
-- slime crowds stacked their name tags into each other and over the quest lines). MonsterService builds one
-- "MonsterBar" BillboardGui per monster (name + Bar/Fill); the server never hides them, this client does:
--   * the name tag shows for the nearest MAX_NAMES monsters within NAME_RANGE studs of me, for any monster hurt in the
--     last HURT_SECONDS (the one I am fighting), and for event bosses (the kings) while in their bar range;
--   * the HP bar under it shows only while the monster was hurt in the last HURT_SECONDS (bosses: always);
--   * a pack crowding one spot shows one name: a same-kind monster within CLUSTER studs of a shown name keeps only its
--     bar (2026-10-06: three ghost minions on top of me stacked "똘마니 유령" three times).
-- Hurt = its Fill bar got shorter (server bar updates replicate). Local only: Enabled / Visible never replicate.
-- Monster barks (lines_pack 2, dev2 BarkService): the server writes Bark (the line) then BarkAt (server time) on the
-- monster model; every new BarkAt (the same line again too) shows Bark in a speech bubble over the head for
-- Config.Barks.Show s, only within Config.Barks.MaxDistance studs; no player names, chat settings do not matter. The
-- bubble is Config.UIArt BarkBubble (9-slice, its tail at the bottom-left sits at the head) or, without that art, a
-- white rounded box with a navy rim. A bark already old when its monster streams in is not shown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MonsterLabels = {}
local LocalPlayer = Players.LocalPlayer

local T = { Tick = 0.2, NameRange = 30, MaxNames = 5, HurtSeconds = 4, Cluster = 5 }
local S = { Started = false, Fill = {}, HurtAt = {} } -- [BillboardGui] = last Fill scale / os.clock() of the last drop
local C = nil
-- bubble: At[model] = the last BarkAt seen (false = none yet); a newer bark replaces the bubble (B.Make)
local B = { At = setmetatable({}, { __mode = "k" }), W = 230, H = 56, H2 = 74,
	LongAt = 24, Lift = 1.1, Text = Color3.fromRGB(28, 36, 82), Rim = Color3.fromRGB(40, 52, 120), Pop = 0.12 }

local function myPos()
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root then return root.Position end
	local cam = workspace.CurrentCamera
	return cam and cam.Focus.Position or nil
end

local function kindOf(model)
	local kind = model:GetAttribute("MonsterKind") or model.Name
	return type(kind) == "string" and kind or model.Name
end

local function isBoss(kind)
	local def = Config.MonsterTypes[kind]
	return type(def) == "table" and def.Boss == true
end

function B.Make(root, offsetY, text)
	local old = root:FindFirstChild("BarkBubble")
	if old then old:Destroy() end
	local cfg = Config.Barks or {}
	local bb = Instance.new("BillboardGui")
	bb.Name = "BarkBubble"
	bb.Size = UDim2.fromOffset(B.W, #text > B.LongAt and B.H2 or B.H)
	bb.SizeOffset = Vector2.new(0.5, 0.5) -- the bubble's bottom-left corner (its tail) at the attach point
	bb.StudsOffset = Vector3.new(0.4, offsetY + B.Lift, 0)
	bb.MaxDistance = tonumber(cfg.MaxDistance) or 60
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	local kit = C and C.UIKit
	local art = nil
	if type(kit) == "table" and type(kit.ArtImage) == "function" then
		local ok, img = pcall(kit.ArtImage, "BarkBubble", { Name = "Art", Size = UDim2.fromScale(1, 1) })
		if ok and img then
			art = img
			art.Parent = bb
		end
	end
	if not art then
		art = Instance.new("Frame")
		art.Name = "Art"
		art.Size = UDim2.fromScale(1, 1)
		art.BackgroundColor3 = Color3.new(1, 1, 1)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = art
		local rim = Instance.new("UIStroke")
		rim.Color = B.Rim
		rim.Thickness = 2
		rim.Parent = art
		art.Parent = bb
	end
	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.BackgroundTransparency = 1
	local rect = Config.UIArt and Config.UIArt.Parts and Config.UIArt.Parts.BarkBubble
	rect = art:IsA("ImageLabel") and type(rect) == "table" and rect.TextRect or { 0.07, 0.15, 0.86, 0.6 }
	label.Position = UDim2.fromScale(rect[1], rect[2])
	label.Size = UDim2.fromScale(rect[3], rect[4])
	label.Text = text
	label.TextColor3 = B.Text
	label.TextWrapped = true
	label.TextScaled = true
	local face = type(kit) == "table" and kit.Theme and kit.Theme.FontFace
	if typeof(face) == "Font" then label.FontFace = face else label.Font = Enum.Font.GothamBold end
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 18
	size.MinTextSize = 11
	size.Parent = label
	label.Parent = art
	local reduced = type(kit) == "table" and type(kit.ReducedMotion) == "function" and kit.ReducedMotion()
	if not reduced then
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = art
		TweenService:Create(scale, TweenInfo.new(B.Pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	bb.Parent = root
	return bb
end

-- the bark check of one monster this tick (called with its MonsterBar's root part)
function B.Check(model, root, barBB, me)
	local at = model:GetAttribute("BarkAt")
	local prev = B.At[model]
	B.At[model] = at or false
	if prev == at then return end
	local cfg = Config.Barks or {}
	if cfg.Enabled == false or type(at) ~= "number" then return end
	if prev == nil and workspace:GetServerTimeNow() - at > (tonumber(cfg.Show) or 3) then return end -- old news
	local text = model:GetAttribute("Bark")
	if type(text) ~= "string" or text == "" then return end
	if me and (root.Position - me).Magnitude > (tonumber(cfg.MaxDistance) or 60) then return end
	local bubble = B.Make(root, barBB and barBB.StudsOffset.Y or 3, text)
	task.delay(tonumber(cfg.Show) or 3, function()
		if bubble.Parent then bubble:Destroy() end -- a newer bark already replaced (destroyed) it otherwise
	end)
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
			local kind = kindOf(model)
			table.insert(rows, { BB = bb, Back = back, Name = bb:FindFirstChild("NameLabel"), D = d, Pos = root.Position,
				Kind = kind, Hurt = hurt, Boss = isBoss(kind) })
			B.Check(model, root, bb, me)
		end
	end
	table.sort(rows, function(a, b) return a.D < b.D end)
	local names, shown = 0, {}
	for _, r in rows do
		local near = r.D <= T.NameRange and names < T.MaxNames
		local name = near or r.Hurt or r.Boss
		if name and not r.Boss then
			for _, o in shown do
				if o.Kind == r.Kind and (o.Pos - r.Pos).Magnitude < T.Cluster then
					name = false
					break
				end
			end
		end
		if name then
			table.insert(shown, r)
			if near then names += 1 end
		end
		local bar = r.Hurt or r.Boss
		local show = name or bar
		if r.BB.Enabled ~= show then r.BB.Enabled = show end
		if r.Name and r.Name.Visible ~= name then r.Name.Visible = name end
		if r.Back and r.Back.Visible ~= bar then r.Back.Visible = bar end
	end
	-- forget bars of monsters that are gone
	for bb in S.Fill do
		if not seen[bb] then
			S.Fill[bb] = nil
			S.HurtAt[bb] = nil
		end
	end
end

function MonsterLabels.Init(registry)
	C = registry
end

-- test aid: the bark check / bubble builder (tools/test_monster_bark.py)
MonsterLabels.Bark = B

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
