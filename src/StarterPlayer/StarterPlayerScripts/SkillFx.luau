-- SkillFx.luau : A23-116 (user 2026-10-10 "최소 18개야, 진영이 2개니까"; docs/design/skills18_2026-10-10.md) - each class x
-- side draws its own skill art. Fx.luau keeps the move, the hit numbers, the shake and the sound and hands the Q art to
-- SkillFx.Q (Fx "Release"); a kit without art here (the artisan guild) keeps Fx's old art. Z / X come with their stage.
-- Rules (the design's §0): no rays / fans / spokes / spiral arms (rings, dots, balls, clouds and single straight lines
-- only); round soft particles without tails; every Part from a pool (Anchored, no collision / query / touch /
-- shadow); ground marks laid on the ground's slope 0.2 above it; ring lines >= 0.6 studs. Budget per cast: BIG = my
-- own manual cast on a PC, SMALL = auto, another player's cast or a phone (T.Budget). Over T.ScreenParts live parts,
-- another player's cast draws only its ground ring and the hit pops.
-- Common signals (drawn only when the server says HP / MP really came in: Fx fields Healed / Stole, game dev 2):
-- Halo heal = gold sparkles over each healed player (up to 5); Horns steal = pink heart dots flying from the first 3
-- hits to my chest + a 0.1 s pink edge on me (my own cast only).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SkillFx = {}
local LocalPlayer = Players.LocalPlayer
local C = nil

local COL = {
	Gold = Color3.fromRGB(255, 215, 90), Cream = Color3.fromRGB(255, 244, 210), White = Color3.fromRGB(255, 255, 255),
	Crimson = Color3.fromRGB(220, 50, 60), Ember = Color3.fromRGB(255, 138, 61), Purple = Color3.fromRGB(155, 77, 255),
	Plum = Color3.fromRGB(58, 30, 74), Pink = Color3.fromRGB(255, 92, 122), Mp = Color3.fromRGB(79, 168, 255),
	Dust = Color3.fromRGB(150, 120, 170),
}
local T = {
	RoundTex = "rbxasset://textures/particles/smoke_main.dds", -- a soft round dot (never a streak)
	Budget = {
		Big = { Parts = 12, Particles = 12, Pops = 6, PopEach = 2, Light = 1 },
		Small = { Parts = 8, Particles = 6, Pops = 3, PopEach = 1, Light = 0 },
	},
	ScreenParts = 60,
	PixelsPerStud = 40, -- ring lines are drawn on a SurfaceGui (UIStroke = studs x this)
	Lift = 0.2,
	HealMax = 5, StealMax = 3,
}
-- Pool[kind] = free parts; Live = parts out now
local S = { Pool = {}, Live = 0, Folder = nil }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function folder()
	if S.Folder and S.Folder.Parent then return S.Folder end
	local f = workspace:FindFirstChild("SkillFx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "SkillFx"
		f.Parent = workspace
	end
	S.Folder = f
	return f
end

local function tween(inst, time, props, style, dir, delayTime)
	local tw = TweenService:Create(inst, TweenInfo.new(math.max(0, time), style or Enum.EasingStyle.Quad,
		dir or Enum.EasingDirection.Out, 0, false, delayTime or 0), props)
	tw:Play()
	return tw
end

----------------------------------------------------------------- the pool
local function bare(kind)
	local p = Instance.new("Part")
	p.Name = "Sfx" .. kind
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Neon
	if kind == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "Ring" or kind == "Disc" then
		-- a flat plate; its top face carries a round frame (Ring: the outline only, Disc: filled)
		p.Transparency = 1
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Face"
		sg.Face = Enum.NormalId.Top
		sg.LightInfluence = 0
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = T.PixelsPerStud
		sg.Parent = p
		local fr = Instance.new("Frame")
		fr.Name = "Round"
		fr.Size = UDim2.fromScale(1, 1)
		fr.BorderSizePixel = 0
		fr.Parent = sg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = fr
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Line"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = fr
		local inner = Instance.new("Frame")
		inner.Name = "Inner"
		inner.BackgroundTransparency = 1
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Parent = fr
		local corner2 = corner:Clone()
		corner2.Parent = inner
		local stroke2 = stroke:Clone()
		stroke2.Name = "Line"
		stroke2.Parent = inner
	elseif kind == "Emit" then
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		local e = Instance.new("ParticleEmitter")
		e.Name = "E"
		e.Enabled = false
		e.Texture = T.RoundTex
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = p
	end
	return p
end

-- a part of this kind from the pool, back after `life` s (its tweens are over by then)
function SkillFx.Get(kind, life)
	local list = S.Pool[kind]
	local p = list and table.remove(list) or bare(kind)
	p.Parent = folder()
	S.Live += 1
	task.delay(math.max(0.05, life), function()
		for _, d in p:GetDescendants() do
			if d:IsA("Trail") or d:IsA("PointLight") or d:IsA("Attachment") then d:Destroy() end
		end
		p.Parent = nil
		S.Live -= 1
		S.Pool[kind] = S.Pool[kind] or {}
		if #S.Pool[kind] < 40 then table.insert(S.Pool[kind], p) else p:Destroy() end
	end)
	return p
end

----------------------------------------------------------------- the ground
local RAY = RaycastParams.new()
RAY.FilterType = Enum.RaycastFilterType.Include

-- the ground under pos -> point, normal (Terrain + workspace.Map.Ground, else the map)
function SkillFx.Ground(pos)
	local map = workspace:FindFirstChild("Map")
	local list = { workspace.Terrain }
	local g = map and map:FindFirstChild("Ground")
	if g or map then table.insert(list, g or map) end
	RAY.FilterDescendantsInstances = list
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), RAY)
	if hit then return hit.Position, hit.Normal end
	return Vector3.new(pos.X, pos.Y, pos.Z), Vector3.yAxis
end

-- a frame lying on the ground at pos (its up = the ground normal), T.Lift above it
local function onGround(pos)
	local at, n = SkillFx.Ground(pos)
	local right = n:Cross(Vector3.zAxis)
	if right.Magnitude < 0.05 then right = Vector3.xAxis end
	right = right.Unit
	return CFrame.fromMatrix(at + n * T.Lift, right, n, right:Cross(n).Unit)
end

----------------------------------------------------------------- primitives
-- a flat round ring (o.Disc = filled) growing From -> To studs across in Grow s, fading out by Life s.
-- o: { From, To, Thick, Color, Inner (a thinner inner line colour), Alpha, Grow, Life, Rise (studs up while it fades),
-- Fill (Disc fill alpha) }
function SkillFx.Ring(pos, o)
	local life = num(o.Life, 0.6)
	local kind = o.Disc and "Disc" or "Ring"
	local p = SkillFx.Get(kind, life + 0.05)
	local cf = o.CFrame or onGround(pos)
	local d0, d1 = math.max(0.3, num(o.From, 2)), math.max(0.3, num(o.To, 18))
	p.Size = Vector3.new(d0, 0.05, d0)
	p.CFrame = cf
	local fr = p.Face.Round
	local line, inner = fr.Line, fr.Inner
	local alpha = num(o.Alpha, 0.15)
	local thick = math.max(0.6, num(o.Thick, 0.8))
	line.Color = o.Color or COL.Gold
	line.Thickness = thick * T.PixelsPerStud
	line.Transparency = alpha
	fr.BackgroundColor3 = o.FillColor or o.Color or COL.Gold
	fr.BackgroundTransparency = o.Disc and num(o.Fill, 0.45) or 1
	inner.Visible = o.Inner ~= nil
	if o.Inner then
		inner.Size = UDim2.new(1, -thick * T.PixelsPerStud * 2, 1, -thick * T.PixelsPerStud * 2)
		inner.Line.Color = o.Inner
		inner.Line.Thickness = math.max(0.25, thick * 0.4) * T.PixelsPerStud
		inner.Line.Transparency = alpha
		tween(inner.Line, life * 0.6, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life * 0.4)
	end
	tween(p, num(o.Grow, 0.2), { Size = Vector3.new(d1, 0.05, d1) })
	tween(line, life * 0.6, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life * 0.4)
	if o.Disc then tween(fr, life * 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life * 0.4) end
	if o.Rise then tween(p, life, { CFrame = cf + Vector3.new(0, o.Rise, 0) }, Enum.EasingStyle.Sine) end
	return p
end

-- a glowing ball (size studs) at pos for life s
function SkillFx.Ball(pos, size, color, life, alpha)
	local p = SkillFx.Get("Ball", life)
	p.Size = Vector3.new(size, size, size)
	p.CFrame = CFrame.new(pos)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = alpha or 0
	return p
end

-- round soft dots: n at pos (o: { Color (Color3 | ColorSequence), Size, Speed, Life, Up (gravity), Spread })
function SkillFx.Dots(pos, n, o)
	if n <= 0 then return end
	local life = num(o.Life, 0.8)
	local p = SkillFx.Get("Emit", life + 0.3)
	p.CFrame = CFrame.new(pos)
	local e = p.E
	local c = o.Color or COL.Gold
	e.Color = typeof(c) == "ColorSequence" and c or ColorSequence.new(c)
	e.LightEmission = num(o.Glow, 0.8)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, num(o.Size, 0.5)), NumberSequenceKeypoint.new(1, num(o.EndSize, 0)) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(num(o.SpeedMin, 2), num(o.Speed, 6))
	e.SpreadAngle = o.Spread or Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, num(o.Up, -12), 0)
	e.Drag = num(o.Drag, 1)
	e.EmissionDirection = o.Dir or Enum.NormalId.Top
	e:Emit(math.clamp(math.floor(n), 1, 40))
end

-- a ball flying a -> b in time s (o.Arc = studs up in the middle), then gone after Linger s
function SkillFx.Fly(a, b, time, size, color, o)
	o = o or {}
	local p = SkillFx.Ball(a, size, color, time + num(o.Linger, 0.15) + 0.05, o.Alpha)
	local arc = num(o.Arc, 0)
	if arc > 0 then
		local mid = (a + b) / 2 + Vector3.new(0, arc, 0)
		tween(p, time / 2, { CFrame = CFrame.new(mid) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween(p, time / 2, { CFrame = CFrame.new(b) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, time / 2)
	else
		tween(p, time, { CFrame = CFrame.new(b) }, o.Style or Enum.EasingStyle.Linear)
	end
	if o.Fade ~= false then tween(p, num(o.Linger, 0.15), { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, time) end
	return p
end

-- a straight arrow from a to b in time s (a thin bar pointing along its flight; no fan, no streak)
function SkillFx.Arrow(a, b, time, color, len)
	len = len or 2.4
	local p = SkillFx.Get("Block", time + 0.25)
	p.Size = Vector3.new(0.2, 0.2, len)
	p.Color = color
	p.Transparency = 0
	p.CFrame = CFrame.lookAt(a, b)
	tween(p, time, { CFrame = CFrame.lookAt(b, b + (b - a).Unit) }, Enum.EasingStyle.Linear)
	tween(p, 0.2, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, time)
	return p
end

-- a soft cloud of `count` (1-2) balls (diameter d) at pos for life s; rim = the second ball's colour
function SkillFx.Cloud(pos, d, color, life, rim, count)
	local offs = { Vector3.new(-d * 0.2, 0, 0), Vector3.new(d * 0.25, d * 0.12, -0.2) }
	for i = 1, math.clamp(count or 2, 1, 2) do
		local off = count == 1 and Vector3.zero or offs[i]
		local s = d * (count == 1 and 0.8 or (i == 2 and 0.7 or 0.65))
		local p = SkillFx.Ball(pos + off, s * 0.4, i == 2 and (rim or color) or color, life, 0.25)
		p.Material = Enum.Material.SmoothPlastic
		tween(p, 0.15, { Size = Vector3.new(s, s, s) }, Enum.EasingStyle.Back)
		tween(p, life * 0.4, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life * 0.6)
	end
end

-- the hit pops: round dots over the nearest hit monsters (BIG 6 x 2, SMALL 3 x 1)
function SkillFx.Pops(hits, color, budget)
	if type(hits) ~= "table" then return end
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local list = {}
	for _, h in hits do
		if type(h) == "table" and typeof(h.P) == "Vector3" then table.insert(list, h.P) end
	end
	if root then table.sort(list, function(a, b) return (a - root.Position).Magnitude < (b - root.Position).Magnitude end) end
	for i = 1, math.min(#list, budget.Pops) do
		SkillFx.Dots(list[i] + Vector3.new(0, 1.5, 0), budget.PopEach, { Color = color, Size = 0.9, EndSize = 0.2,
			Speed = 3, Life = 0.35, Up = 0, Spread = Vector2.new(180, 180) })
	end
end

----------------------------------------------------------------- common signals
-- Halo heal (data.Healed = UserIds that really got HP) / Horns steal (data.Stole > 0, my own cast)
function SkillFx.Signals(data, own)
	if type(data.Healed) == "table" then
		for i, uid in data.Healed do
			if i > T.HealMax then break end
			local p = Players:GetPlayerByUserId(tonumber(uid) or 0)
			local head = p and p.Character and p.Character:FindFirstChild("Head")
			if head then
				SkillFx.Dots(head.Position + Vector3.new(0, 1.6, 0), 3, { Color = COL.Gold, Size = 0.45, Speed = 2, Life = 0.5, Up = 2 })
			end
		end
	end
	local stole = num(data.Stole, 0)
	local root = own and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("UpperTorso")
	if stole > 0 and root and type(data.Hits) == "table" then
		local n = 0
		for _, h in data.Hits do
			if n >= T.StealMax then break end
			if type(h) == "table" and typeof(h.P) == "Vector3" then
				n += 1
				SkillFx.Fly(h.P + Vector3.new(0, 1.5, 0), root.Position, 0.35, 0.45, COL.Pink, { Arc = 1.5 })
			end
		end
		local hl = Instance.new("Highlight")
		hl.FillTransparency, hl.OutlineColor, hl.FillColor = 1, COL.Pink, COL.Pink
		hl.Parent = LocalPlayer.Character
		task.delay(0.1, function() hl:Destroy() end)
	end
end

----------------------------------------------------------------- the six Q
local Q = {}

-- Halo Slam: a gold ball on the sword tip, then a flat gold ring (cream inside) to r9, a small halo ring floating up,
-- round gold sparkles, white hit pops
function Q.Warrior_Halo(c)
	local tip = c.Big and c.Env.Muzzle()
	if tip then
		local orb = SkillFx.Ball(tip, 0.6, COL.Gold, c.Impact + 0.05, 0.1)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local m = orb.Parent and c.Env.Muzzle()
			if not m then conn:Disconnect() return end
			orb.CFrame = CFrame.new(m)
		end)
		task.delay(c.Impact, function() conn:Disconnect() end)
	end
	c.Env.After(c.Impact, function()
		SkillFx.Ring(c.Pos, { From = 2, To = c.Radius * 2, Thick = 0.8, Color = COL.Gold, Inner = COL.Cream, Grow = 0.2, Life = 0.5 })
		SkillFx.Ring(c.Pos, { From = 4, To = 4, Thick = 0.6, Color = COL.Gold, Grow = 0, Life = 0.7, Rise = 3 })
		SkillFx.Dots(c.Ground + Vector3.new(0, 0.6, 0), c.Big and 10 or 5, { Color = COL.Gold, Size = 0.5, Speed = 9, SpeedMin = 5, Life = 0.7 })
		SkillFx.Pops(c.Data.Hits, COL.White, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Crater Smash: an ember trail on the blade, a thick crimson ring (ember inside) then a thin purple one, a shallow
-- plum crater, round toy stones hopping out, rising ember dots turning purple, orange hit pops (no ground cracks)
function Q.Warrior_Horns(c)
	local char = c.Data.Character
	if typeof(char) ~= "Instance" then
		local pl = Players:GetPlayerByUserId(tonumber(c.Data.UserId) or 0)
		char = pl and pl.Character
	end
	local weapon = typeof(char) == "Instance" and char:FindFirstChild("WeaponModel")
	local blade = weapon and weapon:FindFirstChild("Blade", true)
	if blade and c.Big then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, blade.Size.Y * 0.5, 0), Vector3.new(0, -blade.Size.Y * 0.2, 0)
		a0.Parent, a1.Parent = blade, blade
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(COL.Ember, COL.Crimson)
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Lifetime = 0.15
		tr.LightEmission = 0.8
		tr.Parent = blade
		task.delay(c.Impact + 0.15, function() tr:Destroy() a0:Destroy() a1:Destroy() end)
	end
	c.Env.After(c.Impact, function()
		SkillFx.Ring(c.Pos, { From = 2, To = c.Radius * 2, Thick = 1.0, Color = COL.Crimson, Inner = COL.Ember, Grow = 0.15, Life = 0.55 })
		task.delay(0.08, function()
			SkillFx.Ring(c.Pos, { From = 2, To = c.Radius * 2, Thick = 0.6, Color = COL.Purple, Grow = 0.15, Life = 0.5 })
		end)
		SkillFx.Ring(c.Pos, { Disc = true, From = c.Radius * 0.9, To = c.Radius * 1.1, Thick = 0.6, Color = COL.Plum,
			FillColor = COL.Plum, Fill = 0.35, Grow = 0.1, Life = 0.8 })
		local stones = c.Big and 6 or 3
		for i = 1, stones do
			local ang = (i / stones) * math.pi * 2 + math.random() * 0.6
			local from = c.Ground + Vector3.new(math.cos(ang) * 1.5, 0.5, math.sin(ang) * 1.5)
			local to = c.Ground + Vector3.new(math.cos(ang) * (2.5 + math.random()), 0.4, math.sin(ang) * (2.5 + math.random()))
			local p = SkillFx.Fly(from, to, 0.45, 0.8 + math.random() * 0.4, COL.Plum, { Arc = 2 + math.random(), Linger = 0.25 })
			p.Material = Enum.Material.SmoothPlastic
		end
		SkillFx.Dots(c.Ground + Vector3.new(0, 0.5, 0), c.Big and 12 or 6, { Color = ColorSequence.new(COL.Ember, COL.Purple),
			Size = 0.45, Speed = 3, SpeedMin = 1, Life = 1.0, Up = 3 })
		SkillFx.Pops(c.Data.Hits, COL.Ember, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Star Fall: a faint warning ring on the target, a plump round gold star (cream core) falling from 18 up with a
-- short straight trail, a squash and one bounce, a soft gold puff, a gold ring to r9, round star dots
function Q.Mage_Halo(c)
	local warn = math.max(0, c.Impact - 0.2)
	c.Env.After(math.max(0, warn - 0.05), function()
		SkillFx.Ring(c.Pos, { From = c.Radius * 2, To = c.Radius * 2, Thick = 0.6, Color = COL.Gold, Alpha = 0.55, Grow = 0, Life = 0.35 })
	end)
	c.Env.After(warn, function()
		local fall = c.Impact - warn
		local top = c.Ground + Vector3.new(0, 18, 0)
		local star = SkillFx.Fly(top, c.Ground + Vector3.new(0, 1.5, 0), fall, 4, COL.Gold, { Linger = 0.3, Style = Enum.EasingStyle.Quad, Fade = false })
		local core = SkillFx.Fly(top, c.Ground + Vector3.new(0, 1.5, 0), fall, 2.2, COL.Cream, { Linger = 0.3, Style = Enum.EasingStyle.Quad, Fade = false })
		if c.Budget.Light > 0 then
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = COL.Gold, 14, 2
			l.Parent = star
		end
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0.8, 0, 0), Vector3.new(-0.8, 0, 0)
		a0.Parent, a1.Parent = star, star
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(COL.Cream)
		tr.Transparency = NumberSequence.new(0.3, 1)
		tr.Lifetime = 0.15
		tr.LightEmission = 1
		tr.Parent = star
		c.Env.After(fall, function()
			for _, b in { star, core } do
				local s = b.Size.X
				tween(b, 0.08, { Size = Vector3.new(s * 1.3, s * 1.3, s * 1.3), Transparency = 0.3 })
				tween(b, 0.2, { Size = Vector3.new(s * 0.2, s * 0.2, s * 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.08)
			end
		end)
	end)
	c.Env.After(c.Impact, function()
		local puff = SkillFx.Ball(c.Ground + Vector3.new(0, 1, 0), 2, COL.Gold, 0.4, 0.4)
		tween(puff, 0.35, { Size = Vector3.new(9, 9, 9), Transparency = 1 })
		SkillFx.Ring(c.Pos, { From = 2, To = c.Radius * 2, Thick = 0.8, Color = COL.Gold, Grow = 0.15, Life = 0.5 })
		SkillFx.Dots(c.Ground + Vector3.new(0, 1, 0), c.Big and 10 or 5, { Color = COL.Gold, Size = 0.4, Speed = 8, SpeedMin = 4,
			Life = 0.7, Spread = Vector2.new(85, 85) })
		SkillFx.Pops(c.Data.Hits, COL.Cream, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Purple Pop: a purple pool (red rim) opens under the target, round purple bubbles rise up 8, pop into plum smoke
-- with rising ember dots and a purple ring (no spikes, no rays)
function Q.Mage_Horns(c)
	local open = math.max(0, c.Impact - 0.2)
	c.Env.After(open, function()
		SkillFx.Ring(c.Pos, { Disc = true, From = c.Radius * 1.2, To = c.Radius * 2, Thick = 0.6, Color = COL.Crimson,
			FillColor = COL.Purple, Fill = 0.55, Grow = 0.15, Life = 0.45 })
	end)
	c.Env.After(c.Impact, function()
		local n = c.Big and 6 or 4
		for i = 1, n do
			local ang = (i / n) * math.pi * 2 + math.random() * 0.5
			local r = math.random() * c.Radius * 0.55
			local from = c.Ground + Vector3.new(math.cos(ang) * r, 0.5, math.sin(ang) * r)
			SkillFx.Fly(from, from + Vector3.new(0, 8, 0), 0.25, 1 + math.random() * 0.5, COL.Purple,
				{ Style = Enum.EasingStyle.Quad, Linger = 0.08, Alpha = 0.15 })
		end
	end)
	c.Env.After(c.Impact + 0.25, function()
		local top = c.Ground + Vector3.new(0, 7, 0)
		SkillFx.Dots(top, c.Big and 6 or 3, { Color = COL.Plum, Size = 2.2, EndSize = 2.8, Speed = 2, Life = 0.6, Up = 0, Glow = 0,
			Spread = Vector2.new(180, 180) })
		SkillFx.Dots(top, c.Big and 6 or 3, { Color = ColorSequence.new(COL.Ember, COL.Pink), Size = 0.4, Speed = 2, Life = 0.6, Up = 2 })
		SkillFx.Ring(c.Pos, { From = 2, To = c.Radius * 2, Thick = 0.6, Color = COL.Purple, Grow = 0.2, Life = 0.5 })
	end)
	c.Env.After(c.Impact, function()
		SkillFx.Pops(c.Data.Hits, COL.Purple, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- the arrows of a rain: n straight arrows falling side by side at one angle (never a fan) to land from `land` on, one
-- every gap s; a dot where the first `dots` land
local function rain(c, n, land, gap, color, dot, dots)
	local tilt = Vector3.new(1.2, 0, 0.6) -- one shared slant: parallel lines
	for i = 1, n do
		local ang = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * c.Radius * 0.8
		local hit = c.Ground + Vector3.new(math.cos(ang) * r, 0.4, math.sin(ang) * r)
		local start = hit + Vector3.new(0, 16, 0) + tilt * 4
		local at = land + (i - 1) * gap - 0.12
		c.Env.After(math.max(0, at), function()
			SkillFx.Arrow(start, hit, 0.12, color, 2.2)
			if i <= dots then
				task.delay(0.12, function() SkillFx.Dots(hit + Vector3.new(0, 0.3, 0), 1, { Color = dot, Size = 0.5, Speed = 2, Life = 0.4 }) end)
			end
		end)
	end
end

-- Feather Rain: a gold arrow up, a cream cloud over the target, a faint gold ring, 8 gold arrows falling side by
-- side, white feather dots drifting down
function Q.Archer_Halo(c)
	c.Env.After(c.Launch, function()
		local m = c.Env.Muzzle()
		if m then SkillFx.Arrow(m, c.Ground + Vector3.new(0, 30, 0), 0.15, COL.Gold, 2) end
		SkillFx.Cloud(c.Ground + Vector3.new(0, 18, 0), 6, COL.Cream, 0.85, nil, c.Big and 2 or 1)
		SkillFx.Ring(c.Pos, { From = c.Radius * 2, To = c.Radius * 2, Thick = 0.6, Color = COL.Gold, Alpha = 0.5, Grow = 0, Life = 0.6 })
	end)
	rain(c, c.Big and 8 or 5, c.Impact, 0.02, COL.Gold, COL.Cream, c.Big and 8 or 3)
	c.Env.After(c.Impact, function()
		SkillFx.Dots(c.Ground + Vector3.new(0, 10, 0), c.Big and 4 or 2, { Color = COL.White, Size = 0.35, Speed = 1, SpeedMin = 0.5,
			Life = 1.2, Up = -1.5, Glow = 0.3, Spread = Vector2.new(180, 180) })
		SkillFx.Pops(c.Data.Hits, COL.Cream, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Spark Shower: two short dark arrows up, a small plum cloud (pink rim), a thin purple ring, purple arrows falling
-- side by side in two waves (4 at the hit, 4 a beat later), ember dots and smoke puffs
function Q.Archer_Horns(c)
	for _, t in c.Big and { c.Launch, c.Launch + 0.12 } or { c.Launch } do
		c.Env.After(t, function()
			local m = c.Env.Muzzle()
			if m then SkillFx.Arrow(m, c.Ground + Vector3.new(0, 30, 0), 0.15, COL.Plum, 1.6) end
		end)
	end
	c.Env.After(c.Launch, function()
		SkillFx.Cloud(c.Ground + Vector3.new(0, 16, 0), 8, COL.Plum, 0.85, COL.Pink, 1)
		SkillFx.Ring(c.Pos, { From = c.Radius * 2, To = c.Radius * 2, Thick = 0.6, Color = COL.Purple, Alpha = 0.45, Grow = 0, Life = 0.6 })
	end)
	rain(c, c.Big and 4 or 3, c.Impact, 0.015, COL.Purple, COL.Ember, c.Big and 4 or 2)
	rain(c, c.Big and 4 or 2, c.Impact + 0.1, 0.015, COL.Purple, COL.Ember, c.Big and 4 or 1)
	c.Env.After(c.Impact, function()
		SkillFx.Dots(c.Ground + Vector3.new(0, 0.8, 0), c.Big and 4 or 2, { Color = COL.Dust, Size = 1.6, EndSize = 2.2, Speed = 2,
			Life = 0.6, Up = 0.5, Glow = 0, Spread = Vector2.new(180, 180) })
		SkillFx.Pops(c.Data.Hits, COL.Purple, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

SkillFx.Kits = Q

----------------------------------------------------------------- the six Z (A23-116 Z stage; ZEnabled stays off until 10/20)
local Z = {}

-- runs fn(elapsed) every frame for life s (bird / bat flights, a rope, a glow on the bow)
function SkillFx.Follow(life, fn)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > life then conn:Disconnect() return end
		local ok = pcall(fn, t)
		if not ok then conn:Disconnect() end
	end)
	return conn
end

-- pure: where a flier is at time t on points[i] reached at times[i] (arc = studs up mid-hop, 0 = straight dashes)
function SkillFx.PathAt(points, times, t, arc)
	if #points == 0 then return nil end
	if t <= times[1] then return points[1] end
	for i = 2, #points do
		if t <= times[i] then
			local u = (t - times[i - 1]) / math.max(0.001, times[i] - times[i - 1])
			local p = points[i - 1]:Lerp(points[i], u)
			return p + Vector3.new(0, (arc or 0) * math.sin(math.pi * u), 0)
		end
	end
	return points[#points]
end

-- the faint ground band of a Line skill: 3 pieces along dir, each on its own ground height
function SkillFx.Band(from, dir, len, width, color, alpha, life)
	local seg = len / 3
	for i = 1, 3 do
		local mid = from + dir * (seg * (i - 0.5))
		local at = SkillFx.Ground(mid)
		local p = SkillFx.Get("Block", life + 0.05)
		p.Size = Vector3.new(width, 0.1, seg)
		p.Color = color
		p.Material = Enum.Material.Neon
		p.Transparency = alpha
		p.CFrame = CFrame.lookAt(at + Vector3.new(0, T.Lift, 0), at + Vector3.new(0, T.Lift, 0) + dir)
		tween(p, life * 0.5, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life * 0.5)
	end
end

-- a little round flier (the Light Mage's bird / the Dark Mage's bat): body, 2 flapping wings, 2 dot eyes, a beak / rim.
-- Returns its parts; place(cf, t) puts them on the body frame cf (wings flap with t)
local function flier(life, bird)
	local body = SkillFx.Ball(Vector3.zero, 2.5, bird and COL.Gold or COL.Purple, life, 0)
	local parts = { body }
	local wings = {}
	for _ = 1, 2 do
		local w = SkillFx.Get("Block", life)
		w.Size = Vector3.new(1.6, 0.15, 0.9)
		w.Color = bird and COL.White or COL.Purple
		w.Material = Enum.Material.Neon
		w.Transparency = 0
		table.insert(wings, w)
		table.insert(parts, w)
	end
	local eyes = {}
	for _ = 1, 2 do
		local e = SkillFx.Ball(Vector3.zero, bird and 0.3 or 0.45, Color3.fromRGB(30, 24, 40), life, 0)
		e.Material = Enum.Material.SmoothPlastic
		table.insert(eyes, e)
		table.insert(parts, e)
	end
	-- the bird's orange beak / the bat's bright pink rim (so it never reads as a monster)
	local extra = bird and SkillFx.Ball(Vector3.zero, 0.45, COL.Ember, life, 0) or SkillFx.Ball(Vector3.zero, 2.9, COL.Pink, life, 0.65)
	table.insert(parts, extra)
	local function place(cf, t)
		body.CFrame = cf
		local flap = math.rad(40) * math.sin(t * 30)
		wings[1].CFrame = cf * CFrame.new(1.4, 0.3, 0) * CFrame.Angles(0, 0, flap)
		wings[2].CFrame = cf * CFrame.new(-1.4, 0.3, 0) * CFrame.Angles(0, 0, -flap)
		eyes[1].CFrame = cf * CFrame.new(0.45, 0.35, -1.1)
		eyes[2].CFrame = cf * CFrame.new(-0.45, 0.35, -1.1)
		extra.CFrame = bird and (cf * CFrame.new(0, 0.05, -1.3)) or cf
	end
	return parts, place, body
end

-- Glow Lasso: a straight gold rope from the sword tip to a flat cream oval loop that slides 22 ahead, is hauled back
-- with the pulled monsters (manual casts only) and breaks into sparkles
function Z.Warrior_Halo(c)
	c.Env.After(c.Contact, function()
		local far = SkillFx.Ground(c.From + c.Dir * (c.Len * 0.8))
		local near = SkillFx.Ground(c.From + c.Dir * 3)
		local loop = SkillFx.Get("Ring", 0.8)
		loop.Size = Vector3.new(c.Width, 0.05, math.max(3, c.Width * 0.6))
		local fr = loop.Face.Round
		fr.BackgroundTransparency = 1
		fr.Line.Color, fr.Line.Thickness, fr.Line.Transparency = COL.Cream, 0.7 * T.PixelsPerStud, 0.05
		fr.Inner.Visible = false
		local lift = Vector3.new(0, T.Lift, 0)
		loop.CFrame = CFrame.lookAt(near + lift, near + lift + c.Dir)
		tween(loop, 0.15, { CFrame = CFrame.lookAt(far + lift, far + lift + c.Dir) })
		local rope = SkillFx.Get("Block", 0.8)
		rope.Color, rope.Material, rope.Transparency = COL.Gold, Enum.Material.Neon, 0
		SkillFx.Follow(0.5, function()
			local tip = c.Env.Muzzle() or (c.From + Vector3.new(0, 2, 0))
			local to = loop.Position
			local d = (to - tip).Magnitude
			rope.Size = Vector3.new(0.25, 0.25, math.max(0.1, d))
			rope.CFrame = CFrame.lookAt((tip + to) / 2, to)
		end)
		if not c.Auto then
			task.delay(0.16, function()
				local back = SkillFx.Ground(far - c.Dir * 5) + lift
				tween(loop, 0.2, { CFrame = CFrame.lookAt(back, back + c.Dir) })
				SkillFx.Dots(back, c.Big and 4 or 2, { Color = COL.Cream, Size = 0.8, EndSize = 1.2, Speed = 2, Life = 0.5, Up = 1, Glow = 0.2 })
			end)
		end
		task.delay(0.46, function()
			SkillFx.Dots(loop.Position + Vector3.new(0, 0.5, 0), c.Big and 8 or 4, { Color = COL.Gold, Size = 0.45, Speed = 5, Life = 0.6,
				Spread = Vector2.new(180, 180), Up = -4 })
			tween(fr.Line, 0.1, { Transparency = 1 })
			tween(rope, 0.1, { Transparency = 1 })
		end)
		SkillFx.Pops(c.Data.Hits, COL.Gold, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Fire Rake: two sparks off the scraping blade, then one straight orange fire line (crimson rim) running 22 ahead in
-- 3 ground pieces, round ember bubbles rising and turning purple, plum stones rolling ahead; the line cools to purple
function Z.Warrior_Horns(c)
	c.Env.After(0.05, function()
		local tip = c.Env.Muzzle()
		if tip then SkillFx.Dots(tip, c.Big and 2 or 1, { Color = COL.Ember, Size = 0.4, Speed = 4, Life = 0.4 }) end
	end)
	c.Env.After(c.Contact, function()
		local seg = c.Len / 3
		local lines = {}
		for i = 1, 3 do
			local mid = SkillFx.Ground(c.From + c.Dir * (seg * (i - 0.5))) + Vector3.new(0, T.Lift, 0)
			local cf = CFrame.lookAt(mid, mid + c.Dir)
			task.delay((i - 1) * 0.066, function()
				local line = SkillFx.Get("Block", 0.85)
				line.Size, line.Color, line.Material, line.Transparency = Vector3.new(1.2, 0.12, seg), COL.Ember, Enum.Material.Neon, 0
				line.CFrame = cf
				table.insert(lines, line)
				if c.Big then
					local rim = SkillFx.Get("Block", 0.85)
					rim.Size, rim.Color, rim.Material, rim.Transparency = Vector3.new(1.8, 0.08, seg), COL.Crimson, Enum.Material.Neon, 0.35
					rim.CFrame = cf * CFrame.new(0, -0.03, 0)
					tween(rim, 0.3, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0.45)
				end
				SkillFx.Dots(mid, c.Big and (i == 2 and 4 or 3) or (i == 2 and 1 or 2), { Color = ColorSequence.new(COL.Ember, COL.Purple),
					Size = 0.5, Speed = 2, SpeedMin = 1, Life = 0.8, Up = 3 })
				tween(line, 0.2, { Color = COL.Purple }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0.55 - (i - 1) * 0.066)
				tween(line, 0.2, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0.62 - (i - 1) * 0.066)
			end)
		end
		for i = 1, (c.Big and 6 or 3) do
			local from = SkillFx.Ground(c.From + c.Dir * (2 + i * 1.5)) + Vector3.new(0, 0.5, 0)
			local p = SkillFx.Fly(from, from + c.Dir * (3 + math.random() * 2), 0.45, 0.7 + math.random() * 0.3, COL.Plum, { Arc = 1.5, Linger = 0.2 })
			p.Material = Enum.Material.SmoothPlastic
		end
		SkillFx.Pops(c.Data.Hits, COL.Ember, c.Budget)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- the chain fliers' points: the staff tip, then each linked target (1.5 up), first hit at Hit s, one every Gap s
local function chainPath(c, startAt, hitAt, gap)
	local pts, times = {}, {}
	table.insert(pts, c.Env.Muzzle() or (c.From + Vector3.new(0, 3, 0)))
	table.insert(times, 0)
	for i, p in c.Points do
		table.insert(pts, p + Vector3.new(0, 1.5, 0))
		table.insert(times, (hitAt - startAt) + (i - 1) * gap)
	end
	return pts, times
end

-- Birdie Bounce: a round gold bird (white wings, dot eyes, orange beak) hops monster to monster in 3-stud arcs with a
-- gold ribbon, a white pop and two feathers at each hit, then flutters up into sparkles
function Z.Mage_Halo(c)
	if #c.Points == 0 then return end
	c.Env.After(c.Contact, function()
		local pts, times = chainPath(c, c.Contact, c.Hit, 0.1)
		local last = times[#times]
		table.insert(pts, pts[#pts] + Vector3.new(0, 6, 0))
		table.insert(times, last + 0.2)
		local life = last + 0.3
		local parts, place, body = flier(life + 0.1, true)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0)
		a0.Parent, a1.Parent = body, body
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission = a0, a1, 0.4, 1
		tr.Color, tr.Transparency = ColorSequence.new(COL.Gold), NumberSequence.new(0.2, 1)
		tr.Parent = body
		local prev = pts[1]
		SkillFx.Follow(life, function(t)
			local p = SkillFx.PathAt(pts, times, t, 3)
			local face = (p - prev).Magnitude > 0.01 and (p - prev) or Vector3.new(0, 0, -1)
			prev = p
			place(CFrame.lookAt(p, p + face), t)
		end)
		for i = 2, #times - 1 do
			task.delay(times[i], function()
				SkillFx.Dots(pts[i], c.Budget.PopEach, { Color = COL.White, Size = 0.9, EndSize = 0.2, Speed = 3, Life = 0.35, Up = 0, Spread = Vector2.new(180, 180) })
				if c.Big then SkillFx.Dots(pts[i], 2, { Color = COL.White, Size = 0.35, Speed = 1, Life = 0.8, Up = -2, Glow = 0.2 }) end
			end)
		end
		task.delay(life, function()
			SkillFx.Dots(pts[#pts], 4, { Color = COL.Gold, Size = 0.45, Speed = 4, Life = 0.5, Spread = Vector2.new(180, 180) })
			for _, p in parts do p.Transparency = 1 end
		end)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Flappy Zigzag: a round purple bat (pink rim, big dot eyes, no fangs) dashes monster to monster in straight
-- zigzags with a purple-pink ribbon, plum smoke at each hit, then flies home to me (carrying a heart on a real steal)
function Z.Mage_Horns(c)
	if #c.Points == 0 then return end
	c.Env.After(c.Contact, function()
		local pts, times = chainPath(c, c.Contact, c.Hit, 0.1)
		local last = times[#times]
		local root = c.Data.Character and typeof(c.Data.Character) == "Instance" and c.Data.Character:FindFirstChild("UpperTorso")
		local home = root and root.Position or (c.From + Vector3.new(0, 2, 0))
		table.insert(pts, home)
		table.insert(times, last + 0.3)
		local life = last + 0.3
		local parts, place, body = flier(life + 0.1, false)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0)
		a0.Parent, a1.Parent = body, body
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission = a0, a1, 0.4, 0.8
		tr.Color, tr.Transparency = ColorSequence.new(COL.Purple, COL.Pink), NumberSequence.new(0.2, 1)
		tr.Parent = body
		local heart = (c.Own and num(c.Data.Stole, 0) > 0) and SkillFx.Ball(home, 0.5, COL.Pink, life + 0.1, 0) or nil
		local prev = pts[1]
		SkillFx.Follow(life, function(t)
			local p = SkillFx.PathAt(pts, times, t, 0)
			local face = (p - prev).Magnitude > 0.01 and (p - prev) or Vector3.new(0, 0, -1)
			prev = p
			place(CFrame.lookAt(p, p + face), t)
			if heart and t >= last then heart.CFrame = CFrame.new(p + Vector3.new(0, 1.6, 0)) end
		end)
		for i = 2, #times - 1 do
			task.delay(times[i], function()
				SkillFx.Dots(pts[i], c.Budget.PopEach, { Color = COL.Plum, Size = 1.2, EndSize = 1.6, Speed = 2, Life = 0.4, Up = 0, Glow = 0,
					Spread = Vector2.new(180, 180) })
				SkillFx.Dots(pts[i], 1, { Color = COL.Ember, Size = 0.4, Speed = 2, Life = 0.4, Up = 2 })
			end)
		end
		task.delay(life, function()
			if c.Big then SkillFx.Dots(home, 4, { Color = COL.Plum, Size = 1, EndSize = 1.4, Speed = 2, Life = 0.4, Up = 0, Glow = 0,
				Spread = Vector2.new(180, 180) }) end
			for _, p in parts do p.Transparency = 1 end
		end)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- the big line arrow of Comet Arrow / Moon Shot: a glow on the bow while drawing, a faint ground band, the arrow
-- flying the whole line with one straight ribbon tail, dots along its way, a round puff where it ends
local function lineArrow(c, look)
	if c.Big then
		c.Env.After(0, function()
			local glow = SkillFx.Ball(c.From, 0.2, look.Glow, c.Launch + 0.05, 0.1)
			SkillFx.Follow(c.Launch, function(t)
				local m = c.Env.Muzzle()
				if m then
					local s = 0.2 + 0.6 * math.clamp(t / math.max(0.05, c.Launch), 0, 1)
					glow.Size = Vector3.new(s, s, s)
					glow.CFrame = CFrame.new(m)
				end
			end)
		end)
	end
	c.Env.After(c.Launch, function()
		SkillFx.Band(c.From, c.Dir, c.Len, c.Width, look.Band, 0.7, 0.3)
		local start = c.Env.Muzzle() or (c.From + Vector3.new(0, 2, 0))
		local stop = c.From + c.Dir * c.Len + Vector3.new(0, start.Y - c.From.Y, 0)
		local arrow = SkillFx.Arrow(start, stop, 0.15, look.Arrow, 5)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0.6, 0, 2.4), Vector3.new(-0.6, 0, 2.4)
		a0.Parent, a1.Parent = arrow, arrow
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission = a0, a1, 0.4, 1
		tr.Color = look.Trail
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.WidthScale = NumberSequence.new(1, 0)
		tr.Parent = arrow
		if look.Tip then
			local tip = SkillFx.Fly(start + (stop - start).Unit * 2.6, stop + (stop - start).Unit * 2.6, 0.15, 0.8, look.Tip, { Linger = 0.2 })
			tip.Material = Enum.Material.Neon
		end
		for i = 1, 3 do
			local at = start:Lerp(stop, i / 4)
			task.delay(0.15 * i / 4, function()
				SkillFx.Dots(at, c.Big and (i == 2 and 2 or 3) or (i == 2 and 2 or 1), { Color = look.Dots, Size = 0.4, Speed = 2, Life = 0.6,
					Up = look.DotsUp, Spread = Vector2.new(180, 180) })
			end)
		end
		task.delay(0.15, function()
			local puff = SkillFx.Ball(stop, 1, look.Glow, 0.35, 0.3)
			tween(puff, 0.3, { Size = Vector3.new(3, 3, 3), Transparency = 1 })
		end)
		task.delay(0.08, function() SkillFx.Pops(c.Data.Hits, look.Pop, c.Budget) end)
		SkillFx.Signals(c.Data, c.Own)
	end)
end

-- Comet Arrow: a big white-gold arrow with one straight gold tail across the whole line
function Z.Archer_Halo(c)
	lineArrow(c, { Glow = COL.Gold, Band = COL.Gold, Arrow = COL.White, Trail = ColorSequence.new(COL.Gold, COL.Cream),
		Dots = COL.White, DotsUp = 0, Pop = COL.Gold })
end

-- Moon Shot: a dark plum arrow with a glowing purple tip and a purple ribbon (ember edge), ember dots falling
function Z.Archer_Horns(c)
	lineArrow(c, { Glow = COL.Pink, Band = COL.Purple, Arrow = COL.Plum, Trail = ColorSequence.new(COL.Purple, COL.Ember),
		Tip = COL.Purple, Dots = COL.Ember, DotsUp = -10, Pop = COL.Purple })
end

SkillFx.ZKits = Z

-- Fx "Skill" with Slot Z -> true when drawn. env = { Muzzle(), After(s, fn) }. Times from the press: Contact = the hit
-- (packet ContactDelay, else the class's), Hit = a chain's first hit, Launch = an arrow's release
function SkillFx.Z(data, own, env)
	local key = type(data.Class) == "string" and type(data.Faction) == "string" and (data.Class .. "_" .. data.Faction) or nil
	local kit = key and Z[key]
	local from = typeof(data.From) == "Vector3" and data.From or nil
	if not kit or not from or type(env) ~= "table" then return false end
	local dir = typeof(data.Dir) == "Vector3" and Vector3.new(data.Dir.X, 0, data.Dir.Z) or nil
	if not dir or dir.Magnitude < 0.01 then
		local center = typeof(data.Center) == "Vector3" and data.Center or (from + Vector3.new(0, 0, -1))
		dir = Vector3.new(center.X - from.X, 0, center.Z - from.Z)
		if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
	end
	local points = {}
	for _, p in type(data.Points) == "table" and data.Points or {} do
		if typeof(p) == "Vector3" and #points < 6 then table.insert(points, p) end
	end
	local big = own and data.Auto ~= true and not UserInputService.TouchEnabled
	local class = data.Class
	local c = { Data = data, From = from, Dir = dir.Unit, Len = math.clamp(num(data.Len, 22), 2, 60), Width = math.clamp(num(data.Width, 4), 1, 20),
		Points = points, Own = own, Auto = data.Auto == true, Big = big, Budget = big and T.Budget.Big or T.Budget.Small, Env = env,
		Contact = math.clamp(num(data.ContactDelay, class == "Archer" and 0.18 or 0.24), 0, 1),
		Hit = math.clamp(num(data.HitDelay, 0.35), 0, 1),
		Launch = math.clamp(num(data.LaunchDelay, 0.18), 0, 1) }
	kit(c)
	return true
end

-- Fx "Release" -> true when this kit's Q art was drawn (Fx then skips its old art). env = { Muzzle(), After(s, fn) }
function SkillFx.Q(data, pos, radius, impact, own, env)
	local key = type(data.Class) == "string" and type(data.Faction) == "string" and (data.Class .. "_" .. data.Faction) or nil
	local kit = key and Q[key]
	if not kit or typeof(pos) ~= "Vector3" or type(env) ~= "table" then return false end
	local big = own and data.Auto ~= true and not UserInputService.TouchEnabled
	local budget = big and T.Budget.Big or T.Budget.Small
	local ground = (SkillFx.Ground(pos))
	local c = { Data = data, Pos = pos, Ground = ground, Radius = math.clamp(num(radius, 9), 1, 60), Impact = math.clamp(num(impact, 0.3), 0, 1),
		Launch = math.clamp(num(data.LaunchDelay, 0.18), 0, 1), Own = own, Big = big, Budget = budget, Env = env }
	if not own and S.Live > T.ScreenParts then
		-- a crowded screen: another player's cast keeps only its ground ring and the hit pops
		env.After(c.Impact, function()
			SkillFx.Ring(pos, { From = 2, To = c.Radius * 2, Thick = 0.6, Color = COL.White, Grow = 0.15, Life = 0.4 })
			SkillFx.Pops(data.Hits, COL.White, T.Budget.Small)
		end)
		return true
	end
	kit(c)
	return true
end

-- test aid
function SkillFx.LiveParts()
	return S.Live
end

function SkillFx.Init(registry)
	C = registry
end

function SkillFx.Start() end

return SkillFx
