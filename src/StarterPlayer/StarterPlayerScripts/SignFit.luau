-- SignFit.luau (게임성 개발 1; 게임 플레이 2판·3판 2026-10-16): the map's name signs (MapBuilder billboards: travel pad
-- '→ Goblin Woods (Lv 10+)', 'Altar of Fate', the forge / shop / nest labels under workspace.Map) were drawn on top of
-- each other ('Forge' over 'Altar of Fate') and over the left quest goal ('To Otto' under a pad sign). Every Every s
-- this client measures each sign on screen (its TextLabel's text box, else the billboard's box) and, nearest to the
-- camera first, hides one that would overlap a nearer sign or the fixed HUD (the quest goal, the top chips, the war
-- meter, the event chips: T.Keep; Enabled = false on this screen only; only the signs this module hid come back, with
-- Pad px of room so they do not blink at the edge). 최종 검수 10/17 (2차 사진: 'Altar of Fate' under the goose chip).
-- Assumes: the server never toggles these signs' Enabled after building them (it builds them on).
-- Public API: SignFit.Init(C), SignFit.Start(), SignFit.Plan(list, keepOut) -> { [key] = true } (pure: list =
-- { { Key, D, X, Y, W, H, Hid } } centre + size in px, keepOut = { { X, Y, W, H } } top-left + size), SignFit.Pass().
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local SignFit = {}

local T = {
	Every = 0.25, -- s between passes
	Pad = 4, -- px: two boxes this close count as touching
	Back = 8, -- px more room a hidden sign needs before it shows again
	-- the fixed HUD kept clear: name -> "Self" (its own box) | "Children" (each shown child: the status chip row is a wide
	-- frame, only its chips count)
	Keep = { QuestTracker = "Self", WarMeter = "Self", StatusChips = "Children", GooseChip = "Self", PumpkinKingChip = "Self",
		KaijuChip = "Self" },
	-- billboards that are not map signs (name tags, the story marks and bubbles: never hidden)
	Skip = { Nametag = true, StoryNpcMark = true, StoryFindBubble = true, BarkBubble = true, PetNameTag = true },
}
local S = { Started = false, Hid = setmetatable({}, { __mode = "k" }), Signs = setmetatable({}, { __mode = "k" }), At = 0 }

local function overlaps(a, b, pad)
	return a.X - a.W / 2 - pad < b.X + b.W and a.X + a.W / 2 + pad > b.X
		and a.Y - a.H / 2 - pad < b.Y + b.H and a.Y + a.H / 2 + pad > b.Y
end

-- the signs to hide (pure): nearest first, a sign touching a kept one or a keep-out box is hidden
function SignFit.Plan(list, keepOut)
	table.sort(list, function(a, b) return a.D < b.D end)
	local kept, out = {}, {}
	for _, e in list do
		local pad = T.Pad + (e.Hid and T.Back or 0)
		local hide = false
		for _, k in keepOut or {} do
			if overlaps(e, k, pad) then hide = true break end
		end
		if not hide then
			for _, k in kept do
				-- (a kept sign as a top-left box)
				if overlaps(e, { X = k.X - k.W / 2, Y = k.Y - k.H / 2, W = k.W, H = k.H }, pad) then hide = true break end
			end
		end
		if hide then out[e.Key] = true else table.insert(kept, e) end
	end
	return out
end

local function isSign(d)
	return d:IsA("BillboardGui") and not T.Skip[d.Name] and d:FindFirstChildWhichIsA("TextLabel", true) ~= nil
end

local function whereOf(bb)
	local a = bb.Adornee or bb.Parent
	if not a then return nil end
	if a:IsA("BasePart") then return a.Position end
	if a:IsA("Attachment") then return a.WorldPosition end
	if a:IsA("Model") then return a:GetPivot().Position end
	return nil
end

-- a shown GuiObject's box in viewport px (its ScreenGui may sit under the top bar), else nil
local function boxOf(g)
	if not (g and g:IsA("GuiObject") and g.Visible and g.AbsoluteSize.X > 0) then return nil end
	local x = g.Parent
	while x and not x:IsA("LayerCollector") do
		if x:IsA("GuiObject") and not x.Visible then return nil end
		x = x.Parent
	end
	if not (x and x:IsA("ScreenGui") and x.Enabled) then return nil end
	local top = x.IgnoreGuiInset and Vector2.zero or GuiService:GetGuiInset()
	return { X = g.AbsolutePosition.X + top.X, Y = g.AbsolutePosition.Y + top.Y, W = g.AbsoluteSize.X, H = g.AbsoluteSize.Y }
end

-- the fixed HUD's boxes (T.Keep; the instances found once and kept while they live)
S.Found = {}
local function keepBoxes()
	local me = Players.LocalPlayer
	local pg = me and me:FindFirstChildOfClass("PlayerGui")
	local out = {}
	if not pg then return out end
	for name, how in T.Keep do
		local g = S.Found[name]
		if not (g and g.Parent) then
			g = pg:FindFirstChild(name, true)
			S.Found[name] = g
		end
		if g and how == "Children" then
			if boxOf(g) then
				for _, ch in g:GetChildren() do
					local b = boxOf(ch)
					if b then table.insert(out, b) end
				end
			end
		else
			local b = boxOf(g)
			if b then table.insert(out, b) end
		end
	end
	return out
end

-- one pass
function SignFit.Pass()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local camCF = cam.CFrame
	local perPx = cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	local list = {}
	for bb in S.Signs do
		if bb.Parent == nil then S.Signs[bb] = nil continue end
		if not bb.Enabled and not S.Hid[bb] then continue end -- off by someone else
		local pos = whereOf(bb)
		if not pos then continue end
		local d = (pos - camCF.Position).Magnitude
		if d > bb.MaxDistance then
			if S.Hid[bb] then bb.Enabled, S.Hid[bb] = true, nil end
			continue
		end
		local world = pos + camCF:VectorToWorldSpace(bb.StudsOffset) + bb.StudsOffsetWorldSpace
		local p = cam:WorldToViewportPoint(world)
		if p.Z <= 0 then continue end
		local px = perPx / p.Z
		local w = bb.Size.X.Offset + bb.Size.X.Scale * px
		local h = bb.Size.Y.Offset + bb.Size.Y.Scale * px
		local label = bb:FindFirstChildWhichIsA("TextLabel", true)
		local tb = label and label.TextBounds
		if tb and tb.X > 0 and tb.X < w then w = tb.X end
		if tb and tb.Y > 0 and tb.Y < h then h = tb.Y end
		table.insert(list, { Key = bb, D = d, X = p.X, Y = p.Y, W = w, H = h, Hid = S.Hid[bb] == true })
	end
	local hide = SignFit.Plan(list, keepBoxes())
	for _, e in list do
		local bb = e.Key
		if hide[bb] and bb.Enabled then
			bb.Enabled = false
			S.Hid[bb] = true
		elseif not hide[bb] and S.Hid[bb] then
			bb.Enabled = true
			S.Hid[bb] = nil
		end
	end
end

local function watch(map)
	for _, d in map:GetDescendants() do
		if isSign(d) then S.Signs[d] = true end
	end
	map.DescendantAdded:Connect(function(d)
		task.defer(function()
			if d.Parent and isSign(d) then S.Signs[d] = true end
		end)
	end)
end

function SignFit.Init(_registry) end

function SignFit.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		if map then pcall(watch, map) end
	end)
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if now - S.At < T.Every then return end
		S.At = now
		local ok, err = pcall(SignFit.Pass)
		if not ok then warn("[SignFit] " .. tostring(err)) end
	end)
end

SignFit._T = { T = T, S = S }
return SignFit
