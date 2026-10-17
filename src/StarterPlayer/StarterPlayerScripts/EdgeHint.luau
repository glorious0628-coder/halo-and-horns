-- EdgeHint.luau (게임성 개발 1; 큐 #2 '이게 왜 안 돼?', 최종 검수 10/17): the map's edge walls (MapBuilder Wall_MinX /
-- MaxX / MinZ / MaxZ on Config.Map.Bounds) are invisible - walking into one just stopped the character for no reason
-- on screen. Within T.Show studs of an edge this client draws a soft see-through curtain on that edge in front of me
-- (ForceField material, round soft look - no rays), clearer the closer I get; gone when I walk away. Local only (under
-- the camera), never collides, never in a raycast. The server walls are not touched.
-- Public API: EdgeHint.Init(C), EdgeHint.Start(), EdgeHint.Plan(pos, bounds, show) -> { Axis = "X" | "Z", At, Dist } |
-- nil (pure: the nearest edge within show studs), EdgeHint.Alpha(dist, show) -> transparency (pure), EdgeHint.Step().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EdgeHint = {}

local T = {
	Every = 0.1, -- s between steps
	Show = 12, -- studs from the edge: the curtain shows
	W = 18, H = 9, -- studs: the curtain's width along the edge, its height above my feet
	Near = 0.55, Far = 0.95, -- transparency touching / at Show studs
	Color = Color3.fromRGB(190, 220, 255),
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

local function part()
	if S.Part and S.Part.Parent then return S.Part end
	local p = Instance.new("Part")
	p.Name = T.Name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.ForceField
	p.Color = T.Color
	p.Size = Vector3.new(T.W, T.H, 0.2)
	p.Parent = workspace.CurrentCamera
	S.Part = p
	return p
end

function EdgeHint.Step()
	local bounds = type(Config.Map) == "table" and Config.Map.Bounds or nil
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local e = root and EdgeHint.Plan(root.Position, bounds, T.Show) or nil
	if not e then
		if S.Part then S.Part.Transparency = 1 end
		return nil
	end
	local p = part()
	local y = root.Position.Y - 2.5 + T.H / 2
	if e.Axis == "X" then
		p.CFrame = CFrame.new(e.At, y, root.Position.Z) * CFrame.Angles(0, math.rad(90), 0)
	else
		p.CFrame = CFrame.new(root.Position.X, y, e.At)
	end
	p.Transparency = EdgeHint.Alpha(e.Dist, T.Show)
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
