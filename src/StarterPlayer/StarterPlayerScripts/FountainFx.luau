-- FountainFx.luau : flowing water on the plaza fountains, drawn by every client (user 2026-10-07: "물줄기도 나오게 해야지
-- 로블록스 이펙트 사용해서!"). Free Creator Store effect textures only (A23-62: texture ids, no imported scripts; sources in
-- docs/design/skill_vfx_sources.md): a jet from the top spout, thin water streams (Beams with a flowing texture) falling from
-- each bowl rim, droplet splashes + ripples where they land, a few sparkles on the pool, and for the Halo fountain a
-- golden halo ring with one warm light. Specs per fountain model name, as fractions of the model's bounding box (a
-- rescaled model still fits). Phones and "Screen Shake: Off" (or Roblox Reduced Motion) get fewer particles.
-- Everything is client-side (Anchored, no collision / queries / touch) in a "WaterFx" folder inside the model.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local FountainFx = {}
local TAG = "FountainFx"
local C = nil

local TEX = {
	Drop = "rbxassetid://401407269", -- "Fountain (water) particles" (SparkleWays, 458829107)
	Flow = "rbxassetid://6045867277", -- "Water Beam Effect VFX" (EvilArtist, 14582235284): thin soft streams
	Ripple = "rbxassetid://9833214445", -- "Stylized Water Particles Splash Effect RP" (MoonRocket29609, 104302188311459)
	Sparkle = "rbxassetid://244221535", -- "Sparkles Particle" (Nanonauts, 688891088)
}
local COL = {
	Water = Color3.fromRGB(185, 232, 255),
	Foam = Color3.fromRGB(240, 251, 255),
	Gold = Color3.fromRGB(255, 226, 140),
	Halo = Color3.fromRGB(255, 214, 90),
}
-- Y / R are fractions of the bounding box (height / the wider of X and Z); R is measured from the centre
local SPECS = {
	-- Crossroads (Roblox generate_mesh kit, 21 x 20.4 x 21): top spout, small upper bowl, wide scalloped middle bowl,
	-- round pool (rim heights measured with rays on its collision mesh, 2026-10-07)
	K_Fountain = {
		Jet = { Y = 1.0, Up = 9 },
		Curtains = {
			{ FromY = 0.75, FromR = 0.21, ToY = 0.53, ToR = 0.235, Count = 16, Width = 1.3 },
			{ FromY = 0.525, FromR = 0.305, ToY = 0.13, ToR = 0.335, Count = 24, Width = 1.6, Ripples = true },
		},
		Pool = { Y = 0.13, R = 0.42 },
	},
	-- Halo town (Tripo 3b HD, two cloud tiers + a floating halo ring): first guess, tuned when the model is in the place
	Town_Halo_Fountain = {
		Jet = { Y = 0.86, Up = 8 },
		Curtains = {
			{ FromY = 0.62, FromR = 0.24, ToY = 0.18, ToR = 0.28, Count = 20, Width = 1.6, Ripples = true },
		},
		Pool = { Y = 0.17, R = 0.4 },
		Halo = { Y = 1.02, R = 0.18 },
	},
}
local S = { Started = false, Built = setmetatable({}, { __mode = "k" }), Emitters = {} } -- Emitters: { Emitter, Rate, Kind }

local function lowFx()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local shakeOff = false
	local st = C and C.Settings
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, v = pcall(st.Get, "Shake")
		shakeOff = ok and v == false
	end
	local okRm, reduced = pcall(function() return GuiService.ReducedMotionEnabled end)
	return touchOnly, shakeOff or (okRm and reduced == true)
end

-- the base rate times the device / setting factor (sparkles drop most)
local function applyRates()
	local phone, calm = lowFx()
	for _, e in S.Emitters do
		if e.Emitter.Parent then
			local k = 1
			if phone then k *= 0.55 end
			if calm then k *= (e.Kind == "Sparkle" and 0.25 or 0.7) end
			e.Emitter.Rate = e.Rate * k
		end
	end
end

local function seq(points)
	local kp = {}
	for _, p in points do table.insert(kp, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(kp)
end

local function emitter(parent, kind, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = kind
	e.LightInfluence = 0.5
	e.LockedToPart = false
	for k, v in props do e[k] = v end
	e.Parent = parent
	table.insert(S.Emitters, { Emitter = e, Rate = props.Rate or 5, Kind = kind })
	return e
end

local function hubPart(folder, cf)
	local p = Instance.new("Part")
	p.Name = "Hub"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function attach(hub, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = hub
	a.WorldPosition = worldPos
	return a
end

local function build(model, spec)
	if S.Built[model] then return end
	S.Built[model] = true
	local cf, size = model:GetBoundingBox()
	local base = cf.Position - Vector3.new(0, size.Y / 2, 0)
	local H, W = size.Y, math.max(size.X, size.Z)
	local function at(r, y, angle)
		return base + Vector3.new(math.cos(angle) * r * W, y * H, math.sin(angle) * r * W)
	end
	local old = model:FindFirstChild("WaterFx")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "WaterFx"
	folder.Parent = model
	local hub = hubPart(folder, CFrame.new(base))

	-- the jet: a short column out of the top spout, its drops falling back into the top bowl
	if spec.Jet then
		local a = attach(hub, "Jet", at(0, spec.Jet.Y, 0) + Vector3.new(0, 0.2, 0))
		emitter(a, "Jet", {
			Texture = TEX.Drop, EmissionDirection = Enum.NormalId.Top, Rate = 34,
			Speed = NumberRange.new(spec.Jet.Up * 0.85, spec.Jet.Up * 1.1), SpreadAngle = Vector2.new(5, 5),
			Acceleration = Vector3.new(0, -38, 0), Drag = 0.4, Lifetime = NumberRange.new(0.55, 0.75),
			Size = seq({ { 0, 0.25 }, { 0.15, 0.45 }, { 1, 0.2 } }), Transparency = seq({ { 0, 0.15 }, { 0.7, 0.3 }, { 1, 1 } }),
			Color = ColorSequence.new(COL.Water, COL.Foam), LightEmission = 0.3,
		})
		emitter(a, "Spray", {
			Texture = TEX.Drop, EmissionDirection = Enum.NormalId.Top, Rate = 14,
			Speed = NumberRange.new(3, 5), SpreadAngle = Vector2.new(28, 28), Acceleration = Vector3.new(0, -30, 0),
			Lifetime = NumberRange.new(0.5, 0.8), Size = seq({ { 0, 0.2 }, { 1, 0.08 } }),
			Transparency = seq({ { 0, 0.2 }, { 1, 1 } }), Color = ColorSequence.new(COL.Foam), LightEmission = 0.3,
		})
	end

	-- curtains: flowing sheets from each rim (texture runs down), a splash and ripples where they land
	for t, c in spec.Curtains or {} do
		local offset = (t % 2 == 0) and (math.pi / c.Count) or 0
		for i = 1, c.Count do
			local angle = (i - 0.5) / c.Count * math.pi * 2 + offset
			local a0 = attach(hub, "Rim" .. t .. "_" .. i, at(c.FromR, c.FromY, angle))
			local a1 = attach(hub, "Land" .. t .. "_" .. i, at(c.ToR, c.ToY, angle) + Vector3.new(0, 0.1, 0))
			local b = Instance.new("Beam")
			b.Name = "Curtain"
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = TEX.Flow
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 3
			b.TextureSpeed = 1.6
			b.Width0, b.Width1 = c.Width * 0.8, c.Width
			b.FaceCamera = true
			b.Segments = 4
			b.Transparency = seq({ { 0, 0.2 }, { 0.5, 0.3 }, { 1, 0.65 } })
			b.Color = ColorSequence.new(COL.Water, COL.Foam)
			b.LightEmission = 0.6
			b.LightInfluence = 0.5
			b.Parent = a0
			emitter(a1, "Splash", {
				Texture = TEX.Drop, EmissionDirection = Enum.NormalId.Top, Rate = 2.5,
				Speed = NumberRange.new(2.5, 4.5), SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, -28, 0),
				Lifetime = NumberRange.new(0.3, 0.5), Size = seq({ { 0, 0.18 }, { 1, 0.08 } }),
				Transparency = seq({ { 0, 0.25 }, { 1, 1 } }), Color = ColorSequence.new(COL.Foam), LightEmission = 0.25,
			})
			if c.Ripples then
				emitter(a1, "Ripple", {
					Texture = TEX.Ripple, EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
					Rate = 0.4, Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(0.9), Size = seq({ { 0, 0.6 }, { 1, 2.6 } }),
					Transparency = seq({ { 0, 0.35 }, { 1, 1 } }), Color = ColorSequence.new(COL.Foam), LightEmission = 0.2,
				})
			end
		end
	end

	-- a few twinkles on the pool surface
	if spec.Pool then
		local r = spec.Pool.R * W
		local pad = Instance.new("Part")
		pad.Name = "PoolSparkle"
		pad.Anchored, pad.CanCollide, pad.CanQuery, pad.CanTouch, pad.CastShadow = true, false, false, false, false
		pad.Transparency = 1
		pad.Size = Vector3.new(r * 1.6, 0.1, r * 1.6)
		pad.CFrame = CFrame.new(base + Vector3.new(0, spec.Pool.Y * H + 0.15, 0))
		pad.Parent = folder
		emitter(pad, "Sparkle", {
			Texture = TEX.Sparkle, Rate = 4, Speed = NumberRange.new(0), Lifetime = NumberRange.new(0.8, 1.2),
			Size = seq({ { 0, 0 }, { 0.25, 0.5 }, { 1, 0 } }), Transparency = seq({ { 0, 0.1 }, { 1, 0.4 } }),
			Color = ColorSequence.new(COL.Foam, COL.Gold), LightEmission = 1, ZOffset = 0.5,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
		})
	end

	-- the Halo fountain's floating ring is part of its model: a warm glow and slow sparkles around it (one light; the
	-- map keeps under 40)
	if spec.Halo then
		local glow = Instance.new("Part")
		glow.Name = "HaloGlow"
		glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
		glow.Transparency = 1
		local d = spec.Halo.R * W * 2
		glow.Size = Vector3.new(d, 0.4, d)
		glow.CFrame = CFrame.new(base + Vector3.new(0, spec.Halo.Y * H, 0))
		glow.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = COL.Halo
		light.Range = 14
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = glow
		emitter(glow, "HaloSparkle", {
			Texture = TEX.Sparkle, Rate = 3, Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(1, 1.6), Size = seq({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } }),
			Color = ColorSequence.new(COL.Halo, COL.Foam), LightEmission = 1, Transparency = seq({ { 0, 0.1 }, { 1, 0.5 } }),
		})
	end
	applyRates()
end

local function consider(inst)
	local spec = SPECS[inst.Name]
	if not spec or not inst:IsA("Model") then return end
	task.defer(function()
		if inst.Parent then
			local ok, err = pcall(build, inst, spec)
			if not ok then warn("[" .. TAG .. "] build failed for " .. inst:GetFullName() .. ": " .. tostring(err)) end
		end
	end)
end

function FountainFx.Init(registry)
	C = registry
end

function FountainFx.Start()
	if S.Started then return end
	S.Started = true
	for _, d in workspace:GetDescendants() do consider(d) end
	workspace.DescendantAdded:Connect(consider)
	local st = C and C.Settings
	if type(st) == "table" and type(st.Changed) == "table" then
		st.Changed:Connect(function() pcall(applyRates) end)
	end
	pcall(function() GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function() pcall(applyRates) end) end)
	print("[FountainFx] started")
end

-- test aid (Studio Edit preview through require): build on one model now, no listeners; the caller removes the
-- model's "WaterFx" folder afterwards
function FountainFx.BuildOn(model)
	local spec = typeof(model) == "Instance" and SPECS[model.Name]
	if not spec then return false end
	S.Built[model] = nil
	build(model, spec)
	return true
end

-- test aid: how many emitters / beams this client built
function FountainFx.Stats()
	local beams = 0
	for model in S.Built do
		local f = model:FindFirstChild("WaterFx")
		if f then
			for _, d in f:GetDescendants() do if d:IsA("Beam") then beams += 1 end end
		end
	end
	return { Emitters = #S.Emitters, Beams = beams }
end

return FountainFx
