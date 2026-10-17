-- EdgeHint.luau (게임성 개발 1; 큐 #2 '이게 왜 안 돼?', 최종 검수 10/17): the map's edge walls (MapBuilder Wall_MinX /
-- MaxX / MinZ / MaxZ on Config.Map.Bounds) are invisible - walking into one just stopped the character for no reason
-- on screen. Within T.Show studs of an edge this client draws a soft see-through curtain on that edge in front of me,
-- clearer the closer I get; gone when I walk away. Local only (under the camera), never collides, never in a raycast.
-- The server walls are not touched. Game play r7 (a ForceField panel read as a square white sign / wall): an invisible
-- part carries the curtain as a picture - a pale haze on both faces whose every edge fades to nothing (two crossed
-- UIGradients), the whole thing faded by distance (CanvasGroup) - no hard edge, no rays.
-- Public API: EdgeHint.Init(C), EdgeHint.Start(), EdgeHint.Plan(pos, bounds, show) -> { Axis = "X" | "Z", At, Dist } |
-- nil (pure: the nearest edge within show studs), EdgeHint.Alpha(dist, show) -> transparency (pure), EdgeHint.Step().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EdgeHint = {}

local T = {
	Every = 0.1, -- s between steps
	Show = 12, -- studs from the edge: the curtain shows
	W = 22, H = 10, -- studs: the curtain's width along the edge, its height above my feet
	Near = 0.62, Far = 0.97, -- transparency touching / at Show studs
	Color = Color3.fromRGB(205, 228, 255),
	Px = 50, -- SurfaceGui pixels per stud
	Name = "HH_EdgeHint",
}
local S = { Started = false, Part = nil, At = 0 }

-- (pure) the nearest map edge within show studs of pos (flat), else nil
function EdgeHint.Plan(pos, bounds, show)
	if typeof(pos) ~= "Vector3" or type(bounds) ~= "table" then return nil end
	local best = nil
	for _, e in { { "X", bounds.MinX }, { "X", bounds.MaxX }, { "Z", bounds.MinZ }, { "Z", bounds.MaxZ } } do
		local v = tonumber(e[2])
		if v then
			local d = math.abs((e[1] == "X" and pos.X or pos.Z) - v)
			if d <= show and (best == nil or d < best.Dist) then best = { Axis = e[1], At = v, Dist = d } end
		end
	end
	return best
end

-- (pure) the curtain's transparency: Near touching the edge, Far at show studs
function EdgeHint.Alpha(dist, show)
	local k = math.clamp((tonumber(dist) or show) / math.max(show, 1e-3), 0, 1)
	return T.Near + (T.Far - T.Near) * k
end

-- one face's haze: a CanvasGroup (faded as a whole) with a frame whose four edges fade out (a vertical and a horizontal
-- gradient, one inside the other)
local function haze(p, face)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Haze" .. face.Name
	sg.Face = face
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = T.Px
	sg.Adornee = p
	local g = Instance.new("CanvasGroup")
	g.Name = "Group"
	g.Size = UDim2.fromScale(1, 1)
	g.BackgroundTransparency = 1
	g.GroupTransparency = 1
	g.Parent = sg
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) })
	local outer = Instance.new("Frame")
	outer.Size = UDim2.fromScale(1, 1)
	outer.BackgroundTransparency = 1
	outer.Parent = g
	local inner = Instance.new("Frame")
	inner.Size = UDim2.fromScale(1, 1)
	inner.BackgroundColor3 = T.Color
	inner.BorderSizePixel = 0
	inner.Parent = outer
	local gx = Instance.new("UIGradient")
	gx.Transparency = fade
	gx.Parent = inner
	-- the second fade (top / bottom) on a CanvasGroup layer so both multiply
	local layer = Instance.new("CanvasGroup")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = g
	outer.Parent = layer
	local gy = Instance.new("UIGradient")
	gy.Rotation = 90
	gy.Transparency = fade
	gy.Parent = layer
	sg.Parent = p
	return g
end

local function part()
	if S.Part and S.Part.Parent then return S.Part end
	local p = Instance.new("Part")
	p.Name = T.Name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(T.W, T.H, 0.05)
	p.Parent = workspace.CurrentCamera
	S.Part = p
	S.Groups = { haze(p, Enum.NormalId.Front), haze(p, Enum.NormalId.Back) }
	return p
end

local function setAlpha(a)
	for _, g in S.Groups or {} do g.GroupTransparency = a end
end

function EdgeHint.Step()
	local bounds = type(Config.Map) == "table" and Config.Map.Bounds or nil
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local e = root and EdgeHint.Plan(root.Position, bounds, T.Show) or nil
	if not e then
		setAlpha(1)
		return nil
	end
	local p = part()
	local y = root.Position.Y - 2.5 + T.H / 2
	if e.Axis == "X" then
		p.CFrame = CFrame.new(e.At, y, root.Position.Z) * CFrame.Angles(0, math.rad(90), 0)
	else
		p.CFrame = CFrame.new(root.Position.X, y, e.At)
	end
	setAlpha(EdgeHint.Alpha(e.Dist, T.Show))
	return e
end

function EdgeHint.Init(_registry) end

function EdgeHint.Start()
	if S.Started then return end
	S.Started = true
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if now - S.At < T.Every then return end
		S.At = now
		local ok, err = pcall(EdgeHint.Step)
		if not ok then warn("[EdgeHint] " .. tostring(err)) end
	end)
end

EdgeHint._T = { T = T, S = S }
return EdgeHint
