-- FountainFx (게임성 개발 1, 2026-10-09 night; 검수: the 3-tier Halo fountain, docs/design/halo_town_plan_2026-10-09.md
-- last section): runs the real FountainFx.luau (tools/test_fountain_fx.py) on doubles: services, Instance.new recording
-- every object, models with a bounding box, children and attributes. Input: FX_SOURCE. Every check is named and counted.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function cf(p) return { Position = p } end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local made = {}
local function obj(c)
	local o = { ClassName = c, Children = {} }
	function o.IsA(_, k) return k == c end
	function o.FindFirstChild(self, n, deep)
		for _, ch in self.Children do
			if ch.Name == n then return ch end
			if deep then
				local f = ch:FindFirstChild(n, true)
				if f then return f end
			end
		end
		return nil
	end
	function o.GetDescendants(self)
		local out = {}
		for _, ch in self.Children do
			table.insert(out, ch)
			for _, d in ch:GetDescendants() do table.insert(out, d) end
		end
		return out
	end
	function o.Destroy(self) self.Parent = nil end
	return setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v.Children then table.insert(v.Children, t) end
	end })
end
local Instance = { new = function(c)
	local o = obj(c)
	table.insert(made, o)
	return o
end }
local function model(name, size, opts)
	opts = opts or {}
	local m = obj("Model")
	m.Name = name
	m.Attrs = opts.Attrs or {}
	function m.GetAttribute(_, k) return m.Attrs[k] end
	function m.GetBoundingBox() return cf(vec(10, size.Y / 2, 20)), size end
	function m.GetFullName() return "Workspace." .. name end
	if opts.Mesh then
		local mesh = obj("MeshPart")
		mesh.Name = opts.Mesh
		mesh.Parent = m
	end
	return m
end
local waits = {}
local env = setmetatable({
	Vector3 = { new = vec }, Vector2 = { new = vec }, CFrame = { new = cf }, Enum = enum, Instance = Instance,
	Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end },
	NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end },
	NumberSequence = { new = function(k) return { Keys = k } end }, NumberSequenceKeypoint = { new = function(t, v) return { t, v } end },
	ColorSequence = { new = function(a, b) return { A = a, B = b or a } end },
	game = { GetService = function(_, n)
		if n == "UserInputService" then return { TouchEnabled = false, KeyboardEnabled = true } end
		if n == "GuiService" then return { ReducedMotionEnabled = false } end
		return {}
	end },
	workspace = { GetDescendants = function() return {} end, DescendantAdded = { Connect = function() end } },
	task = { defer = function(f) f() end, wait = function(t) table.insert(waits, t) if waits.OnWait then waits.OnWait() end end },
	warn = function(...) print("WARN", ...) end, print = function() end,
	typeof = function(v) if type(v) == "table" and v.ClassName then return "Instance" end return typeof(v) end,
}, { __index = getfenv() })
local f = assert(loadstring(FX_SOURCE, "=FountainFx"))
setfenv(f, env)
local Fx = f()

local function inFx(m, cls, name)
	local out = {}
	local folder = m:FindFirstChild("WaterFx")
	if not folder then return out end
	for _, d in folder:GetDescendants() do
		if d.ClassName == cls and (name == nil or d.Name == name or string.match(d.Name or "", "^" .. name)) then table.insert(out, d) end
	end
	return out
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

local SIZE3 = vec(16, 12.85, 16)
local base = vec(10, 0, 20)

-- 1. the 3-tier fountain, told by its mesh name
local m3 = model("Town_Halo_Fountain", SIZE3, { Mesh = "Halo_Fountain" })
local spec, key = Fx.SpecFor(m3)
check(key == "Town_Halo_Fountain3", "a Town_Halo_Fountain with a Halo_Fountain mesh = the 3-tier spec", key)
check(Fx.BuildOn(m3), "builds")
check(#inFx(m3, "Part", "HaloGlow") == 0 and #inFx(m3, "PointLight") == 0, "no halo ring glow, no light (the new one has no ring)")
local jet = inFx(m3, "Attachment", "Jet")[1]
check(jet and near(jet.WorldPosition.Y, 0.80 * 12.85 + 0.2), "the jet at the gold ball (Y 0.80)", jet and jet.WorldPosition.Y)
check(#inFx(m3, "Attachment", "Rim1_") == 8 and #inFx(m3, "Attachment", "Rim2_") == 12,
	"8 streams from the top bowl, 12 from the middle rim", #inFx(m3, "Attachment", "Rim1_") .. "/" .. #inFx(m3, "Attachment", "Rim2_"))
local rim1 = inFx(m3, "Attachment", "Rim1_")[1]
local d1 = (rim1.WorldPosition - vec(base.X, rim1.WorldPosition.Y, base.Z)).Magnitude
check(near(rim1.WorldPosition.Y, 0.76 * 12.85) and near(d1, 0.145 * 16), "top bowl streams leave its rim (Y 0.76, R 0.145)", d1)
local land1 = inFx(m3, "Attachment", "Land1_")[1]
check(near(land1.WorldPosition.Y, 0.54 * 12.85 + 0.1), "... and land in the middle bowl (Y 0.54)", land1.WorldPosition.Y)
local rim2 = inFx(m3, "Attachment", "Rim2_")[1]
local d2 = (rim2.WorldPosition - vec(base.X, rim2.WorldPosition.Y, base.Z)).Magnitude
check(near(rim2.WorldPosition.Y, 0.55 * 12.85) and near(d2, 0.25 * 16), "middle rim streams (Y 0.55, R 0.25)", d2)
local land2 = inFx(m3, "Attachment", "Land2_")[1]
local dl2 = (land2.WorldPosition - vec(base.X, land2.WorldPosition.Y, base.Z)).Magnitude
check(near(land2.WorldPosition.Y, 0.17 * 12.85 + 0.1) and dl2 < 0.455 * 16, "... land inside the pool", dl2)
check(#inFx(m3, "ParticleEmitter", "Ripple") == 12, "ripples where the pool streams land", #inFx(m3, "ParticleEmitter", "Ripple"))
local pad = inFx(m3, "Part", "PoolSparkle")[1]
check(pad and near(pad.CFrame.Position.Y, 0.165 * 12.85 + 0.15), "pool twinkles on the water (Y 0.165)", pad and pad.CFrame.Position.Y)
local half = pad.Size.X / 2
check(math.sqrt(2) * half < 0.455 * 16, "the twinkle square stays inside the round pool (corners too)", math.sqrt(2) * half)
local sp = inFx(m3, "ParticleEmitter", "Sparkle")[1]
check(sp.Rate == 8 and sp.Color.A.B > sp.Color.A.R + 100, "more twinkles, in a deeper blue", tostring(sp.Rate))

-- 2. the attribute mark works too; the cloud fountain keeps its own spec
local ma = model("Town_Halo_Fountain", SIZE3, { Attrs = { FountainSpec = "Town_Halo_Fountain3" } })
check(select(2, Fx.SpecFor(ma)) == "Town_Halo_Fountain3", "FountainSpec = Town_Halo_Fountain3 marks it as well")
local mOld = model("Town_Halo_Fountain", vec(16, 12.4, 16), { Mesh = "Town_Halo_Fountain_HD" })
check(select(2, Fx.SpecFor(mOld)) == "Town_Halo_Fountain", "the cloud fountain (no mark) keeps the cloud spec")
Fx.BuildOn(mOld)
check(#inFx(mOld, "Part", "HaloGlow") == 1 and #inFx(mOld, "PointLight") == 1, "... with its halo ring glow and one light")
local mK = model("K_Fountain", vec(21, 20.4, 21))
check(select(2, Fx.SpecFor(mK)) == "K_Fountain", "the Crossroads fountain unchanged")
check(Fx.SpecFor(model("Rock", vec(2, 2, 2))) == nil, "anything else: no spec")

print(("FOUNTAIN_FX_SUMMARY checks=%d failed=%d"):format(checks, failed))
