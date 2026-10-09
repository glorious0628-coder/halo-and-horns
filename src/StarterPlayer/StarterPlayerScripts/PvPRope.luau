-- PvPRope.luau (게임성 개발 1; SPEC A23-90 "경계에 잘 보이는 표시", 검수 queue 2026-10-09 "빨강·흰 줄 + 작은 깃발,
-- 빛 없음"): the rope that shows where players may fight players, drawn by each client from Config.PvPRope. Red and
-- white stripes on short wooden posts with small red pennants, never Neon / lights / glow. Lines: Config.PvPRope.Lines
-- (the Goblin Woods edge at the meadow bridge); Areas: a rope round every zone's PvPArea (the ruins' Crown Pit, A23-90)
-- with an opening in the middle of each side. A line is built the first time I come within BuildRange studs (the
-- posts stand on the terrain under them: one downward ray each) and stays. Local only: a client folder
-- workspace.ClientPvPRope, nothing collides, is touched, queried or casts a shadow; the server never sees it.
-- Public API: PvPRope.Init(C), PvPRope.Start(), PvPRope.Segments(cfg, zones) -> { { A, B, Flags = { [i] = true } } }
-- (pure: posts along each line / area side, the openings left out), PvPRope.Built() -> number of built groups.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local PvPRope = {}
local TAG = "PvPRope"
local S = { Started = false, Folder = nil, Groups = nil, Built = 0 }

local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function cfg()
	return type(Config.PvPRope) == "table" and Config.PvPRope or {}
end

-- posts every PostGap studs from a to b (flat), both ends included; gaps = { { from, to } } in studs along the line
-- leave openings (no post / rope inside, a flagged post on each side). Returns runs: { { Posts = { Vector3 }, Flags } }
local function runsAlong(a, b, gaps, postGap, flagEvery)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = d.Magnitude
	if len < 1 then return {} end
	local dir = d / len
	local cuts = {}
	for _, g in gaps or {} do
		local g1, g2 = num(g[1], 0), num(g[2], 0)
		if g2 > g1 then table.insert(cuts, { math.max(0, g1), math.min(len, g2) }) end
	end
	table.sort(cuts, function(x, y) return x[1] < y[1] end)
	local spans, at = {}, 0
	for _, c in cuts do
		if c[1] > at then table.insert(spans, { at, c[1] }) end
		at = math.max(at, c[2])
	end
	if at < len then table.insert(spans, { at, len }) end
	local runs = {}
	for _, sp in spans do
		local s0, s1 = sp[1], sp[2]
		if s1 - s0 >= 1 then
			local n = math.max(1, math.ceil((s1 - s0) / postGap))
			local run = { Posts = {}, Flags = {} }
			for i = 0, n do
				local s = s0 + (s1 - s0) * i / n
				table.insert(run.Posts, Vector3.new(a.X + dir.X * s, 0, a.Z + dir.Z * s))
				if i == 0 or i == n or i % flagEvery == 0 then run.Flags[i + 1] = true end
			end
			table.insert(runs, run)
		end
	end
	return runs
end

-- every run of posts: Config lines + the four sides of each zone's PvPArea (an opening of AreaGap in each side's
-- middle). Pure. zones = Config.Zones. Each run: { Group (line / area name), Center (for BuildRange), Posts, Flags }
function PvPRope.Segments(c, zones)
	c = type(c) == "table" and c or {}
	local postGap = math.max(2, num(c.PostGap, 8))
	local flagEvery = math.max(1, math.floor(num(c.FlagEvery, 3)))
	local out = {}
	for i, line in (type(c.Lines) == "table" and c.Lines or {}) do
		if typeof(line.From) == "Vector3" and typeof(line.To) == "Vector3" then
			for _, run in runsAlong(line.From, line.To, line.Gaps, postGap, flagEvery) do
				run.Group = "Line" .. i
				run.Center = (line.From + line.To) / 2
				table.insert(out, run)
			end
		end
	end
	if c.Areas ~= false then
		local gap = math.max(0, num(c.AreaGap, 16))
		local ids = {}
		for id in (type(zones) == "table" and zones or {}) do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ids do
			local area = type(zones[id]) == "table" and zones[id].PvPArea or nil
			if type(area) == "table" and typeof(area.Center) == "Vector3" and typeof(area.Size) == "Vector3" then
				local cx, cz, hx, hz = area.Center.X, area.Center.Z, area.Size.X / 2, area.Size.Z / 2
				local corners = { Vector3.new(cx - hx, 0, cz - hz), Vector3.new(cx + hx, 0, cz - hz),
					Vector3.new(cx + hx, 0, cz + hz), Vector3.new(cx - hx, 0, cz + hz) }
				for k = 1, 4 do
					local a, b = corners[k], corners[k % 4 + 1]
					local len = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
					local gaps = gap > 0 and { { len / 2 - gap / 2, len / 2 + gap / 2 } } or nil
					for _, run in runsAlong(a, b, gaps, postGap, flagEvery) do
						run.Group = "Area_" .. id
						run.Center = area.Center
						table.insert(out, run)
					end
				end
			end
		end
	end
	return out
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

local function groundY(pos, params)
	local ok, hit = pcall(function()
		return workspace:Raycast(Vector3.new(pos.X, pos.Y + 120, pos.Z), Vector3.new(0, -260, 0), params)
	end)
	return ok and hit and hit.Position.Y or 0
end

-- one run: posts on the ground, the striped rope between post tops, a small red pennant on flagged posts
local function buildRun(run, parent, params)
	local c = cfg()
	local postH, ropeH = num(c.PostHeight, 3), num(c.RopeHeight, 2.4)
	local thick, stripe = num(c.RopeThick, 0.22), math.max(0.5, num(c.StripeLen, 2))
	local red = typeof(c.Red) == "Color3" and c.Red or Color3.fromRGB(205, 45, 45)
	local white = typeof(c.White) == "Color3" and c.White or Color3.fromRGB(245, 245, 240)
	local wood = typeof(c.Post) == "Color3" and c.Post or Color3.fromRGB(110, 80, 50)
	local flagSize = typeof(c.FlagSize) == "Vector3" and c.FlagSize or Vector3.new(0.1, 1.1, 1.5)
	local tops = {}
	for i, p in run.Posts do
		local y = groundY(p, params)
		part({ Name = "Post", Size = Vector3.new(0.45, postH, 0.45), CFrame = CFrame.new(p.X, y + postH / 2, p.Z), Color = wood,
			Material = Enum.Material.Wood }, parent)
		tops[i] = Vector3.new(p.X, y + ropeH, p.Z)
		if run.Flags[i] then
			local nextP = run.Posts[i + 1] or run.Posts[i - 1]
			local along = nextP and Vector3.new(nextP.X - p.X, 0, nextP.Z - p.Z) or Vector3.new(1, 0, 0)
			along = along.Magnitude > 0.01 and along.Unit or Vector3.new(1, 0, 0)
			-- a small pennant at the post top, along the rope
			local base = Vector3.new(p.X, y + postH - flagSize.Y / 2, p.Z) + along * (flagSize.Z / 2 + 0.2)
			local w = Instance.new("WedgePart")
			w.Name = "Flag"
			w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
			w.Material = Enum.Material.Fabric
			w.Color = red
			w.Size = flagSize
			-- a WedgePart turned upside down round its length: the top edge level from the post out, tapering down to it
			w.CFrame = CFrame.lookAt(base, base + along) * CFrame.Angles(0, 0, math.pi)
			w.Parent = parent
		end
	end
	for i = 1, #tops - 1 do
		local a, b = tops[i], tops[i + 1]
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / stripe + 0.5))
		for k = 0, n - 1 do
			local p0 = a:Lerp(b, k / n)
			local p1 = a:Lerp(b, (k + 1) / n)
			part({ Name = "Rope", Size = Vector3.new(thick, thick, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Color = k % 2 == 0 and red or white }, parent)
		end
	end
end

local function folder()
	if S.Folder and S.Folder.Parent then return S.Folder end
	local f = workspace:FindFirstChild("ClientPvPRope")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClientPvPRope"
		f.Parent = workspace
	end
	S.Folder = f
	return f
end

-- build every group I am within BuildRange of (once each)
local function tick()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local range = num(cfg().BuildRange, 260)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	for name, g in S.Groups do
		if not g.Done and Util.FlatDistance(root.Position, g.Center) <= range + g.Reach then
			g.Done = true
			local model = Instance.new("Model")
			model.Name = name
			for _, run in g.Runs do
				local ok, err = pcall(buildRun, run, model, params)
				if not ok then Util.Warn(TAG, "build " .. name .. ": " .. tostring(err)) end
			end
			model.Parent = folder()
			S.Built += 1
		end
	end
end

function PvPRope.Built()
	return S.Built
end

function PvPRope.Init(_registry) end

function PvPRope.Start()
	if S.Started or cfg().Enabled == false then return end
	S.Started = true
	S.Groups = {}
	for _, run in PvPRope.Segments(cfg(), Config.Zones) do
		local g = S.Groups[run.Group]
		if not g then
			g = { Runs = {}, Center = run.Center, Reach = 0, Done = false }
			S.Groups[run.Group] = g
		end
		table.insert(g.Runs, run)
		for _, p in run.Posts do
			g.Reach = math.max(g.Reach, Util.FlatDistance(p, g.Center))
		end
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then Util.Warn(TAG, tostring(err)) end
			local left = false
			for _, g in S.Groups do if not g.Done then left = true end end
			if not left then break end
			task.wait(1)
		end
	end)
end

return PvPRope
