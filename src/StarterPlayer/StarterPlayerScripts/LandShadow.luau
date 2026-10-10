-- LandShadow.luau : A23-113 ① (user 2026-10-10 "마감 전 넣자") - about a second before a big landing (the King Slime's hop,
-- the first-KO King's drop, the Pumpkin King, the Clatter Captain) a round soft shadow lies on the ground where it lands.
-- The rule never changes: outside the circle = not hit. A faint round disc that darkens until the landing, with a
-- second round disc growing inside it to the rim at the landing moment (the timing), then a short fade. No text, no
-- rays (the 2026-10-07 ray-burst rule), no sound of its own. Everything is client-side (Anchored, no collision / queries
-- / touch) in workspace.LandShadows.
-- Server contract (게임성 개발 2; the first-KO King already sends the first two): monster model attributes
--   DropAt     = server time the warning starts (a new value = a new circle; the same landing never draws twice)
--   DropTime   = s from DropAt to the landing (clamped to Config.LandShadow.MaxTime)
--   DropRadius = studs of the hit circle (optional; else Config.LandShadow.Radius[kind], else Radius.Default)
--   DropPos    = Vector3 landing spot (optional; else the ground under the model's root when the warning starts)
-- Another player's personal monster (OwnerUserId, CR-L15: I cannot see or hit it) draws nothing; nor does one farther
-- than MaxDistance studs or a warning already over when it streams in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local LandShadow = {}
local LocalPlayer = Players.LocalPlayer
local C = nil
local T = type(Config.LandShadow) == "table" and Config.LandShadow or {}
local S = { Seen = setmetatable({}, { __mode = "k" }), Live = {}, Conns = setmetatable({}, { __mode = "k" }), Folder = nil }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or os.clock()
end

-- pure: the circle of one landing, or nil. a = { DropAt, DropTime, DropRadius, Kind }; now = server time.
-- -> { Start = server time, Land = server time, Radius = studs }
function LandShadow.Plan(a, now)
	a = type(a) == "table" and a or {}
	local at, dur = num(a.DropAt, nil), num(a.DropTime, nil)
	if not at or not dur or dur <= 0 then return nil end
	dur = math.min(dur, num(T.MaxTime, 3))
	local land = at + dur
	if now >= land + num(T.Linger, 0.15) then return nil end -- already over (streamed in late)
	local radii = type(T.Radius) == "table" and T.Radius or {}
	local r = num(a.DropRadius, nil) or num(radii[a.Kind or ""], nil) or num(radii.Default, 10)
	r = math.clamp(r, num(T.MinRadius, 3), num(T.MaxRadius, 40))
	return { Start = at, Land = land, Radius = r }
end

-- pure: how the circle looks at server time now -> outer transparency, inner disc share of the radius (0..1), done
-- (true once the fade after the landing is over). Darker as the landing comes; the inner disc reaches the rim then.
function LandShadow.Look(plan, now)
	local span = math.max(plan.Land - plan.Start, 0.05)
	local k = math.clamp((now - plan.Start) / span, 0, 1)
	local a0, a1 = num(T.StartAlpha, 0.85), num(T.EndAlpha, 0.4)
	local alpha = a0 + (a1 - a0) * k
	local after = now - plan.Land - num(T.Linger, 0.15)
	if after > 0 then
		local fade = num(T.Fade, 0.25)
		if after >= fade then return 1, 1, true end
		alpha += (1 - alpha) * (after / fade)
	end
	return alpha, k, false
end

local function groundUnder(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	local ground = map and map:FindFirstChild("Ground")
	table.insert(list, ground or map)
	params.FilterDescendantsInstances = list
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

local function disc(name, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = 1
	p.Parent = parent
	return p
end

local function folder()
	if S.Folder and S.Folder.Parent then return S.Folder end
	local f = workspace:FindFirstChild("LandShadows")
	if not f then
		f = Instance.new("Folder")
		f.Name = "LandShadows"
		f.Parent = workspace
	end
	S.Folder = f
	return f
end

local function myPos()
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- a new DropAt on a monster: draw its circle (once per DropAt value)
function LandShadow.Check(model)
	if not model or not model.Parent then return end
	local at = model:GetAttribute("DropAt")
	if type(at) ~= "number" or S.Seen[model] == at then return end
	S.Seen[model] = at
	local owner = model:GetAttribute("OwnerUserId")
	if owner ~= nil and owner ~= LocalPlayer.UserId then return end -- another player's personal monster (CR-L15)
	local plan = LandShadow.Plan({ DropAt = at, DropTime = model:GetAttribute("DropTime"),
		DropRadius = model:GetAttribute("DropRadius"), Kind = model:GetAttribute("MonsterKind") or model.Name }, serverNow())
	if not plan then return end
	local spot = model:GetAttribute("DropPos")
	if typeof(spot) ~= "Vector3" then
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not root then return end
		spot = groundUnder(root.Position)
	end
	local me = myPos()
	if me and (me - spot).Magnitude > num(T.MaxDistance, 160) then return end
	local f = folder()
	local h = num(T.Height, 0.08)
	local outer = disc("LandShadow", T.Color or Color3.fromRGB(40, 22, 30), f)
	local inner = disc("LandShadowFill", T.FillColor or T.Color or Color3.fromRGB(40, 22, 30), f)
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	outer.Size = Vector3.new(h, plan.Radius * 2, plan.Radius * 2)
	outer.CFrame = CFrame.new(spot + Vector3.new(0, h / 2 + 0.03, 0)) * flat
	plan.Outer, plan.Inner, plan.Spot, plan.Flat, plan.H = outer, inner, spot, flat, h
	table.insert(S.Live, plan)
	LandShadow.Step()
end

-- every frame: darken, grow the inner disc, fade out after the landing
function LandShadow.Step()
	if #S.Live == 0 then return end
	local now = serverNow()
	for i = #S.Live, 1, -1 do
		local p = S.Live[i]
		local alpha, k, done = LandShadow.Look(p, now)
		if done or not p.Outer.Parent then
			p.Outer:Destroy()
			p.Inner:Destroy()
			table.remove(S.Live, i)
			continue
		end
		p.Outer.Transparency = alpha
		local d = math.max(p.Radius * 2 * k, 0.05)
		p.Inner.Size = Vector3.new(p.H, d, d)
		p.Inner.CFrame = CFrame.new(p.Spot + Vector3.new(0, p.H / 2 + 0.06, 0)) * p.Flat
		p.Inner.Transparency = alpha -- over the outer disc: the grown part reads darker
	end
end

local function watch(model)
	if not model:IsA("Model") or S.Conns[model] then return end
	S.Conns[model] = model:GetAttributeChangedSignal("DropAt"):Connect(function() LandShadow.Check(model) end)
	LandShadow.Check(model)
end

function LandShadow.Init(registry)
	C = registry
end

function LandShadow.Start()
	task.spawn(function()
		local monsters = workspace:WaitForChild("Monsters", 30)
		if not monsters then return end
		for _, m in monsters:GetChildren() do pcall(watch, m) end
		monsters.ChildAdded:Connect(function(m) pcall(watch, m) end)
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(LandShadow.Step)
		if not ok then warn("[LandShadow] " .. tostring(err)) end
	end)
end

-- test aid: live circles
function LandShadow.Live()
	return #S.Live
end

return LandShadow
