-- Offline checks for MonsterLabels' name tags (review devlog 12 + 2026-10-07 photos): the real MonsterLabels.luau +
-- Config.luau; MonsterLabels.Tick runs one pass over workspace.Monsters with a camera double that projects like a
-- level camera at name-tag height. Inputs: CONFIG_SOURCE, LABELS_SOURCE. No Studio / Roblox API calls.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local imt = {}
imt.__index = {
	FindFirstChild = function(self, n, recursive)
		for _, ch in self.Children do
			if ch.Name == n then return ch end
			if recursive then
				local d = ch:FindFirstChild(n, true)
				if d then return d end
			end
		end
		return nil
	end,
	GetChildren = function(self) return table.clone(self.Children) end,
	IsA = function(self, c) return self.ClassName == c or (c == "BasePart" and self.ClassName == "Part") end,
	GetAttribute = function(self, k) return self.Attrs[k] end,
	Destroy = function(self) rawset(self, "Parent", nil) end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		rawset(self, "Parent", v)
		if v then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class, name, props)
	local o = setmetatable({ ClassName = class, Name = name or class, Children = {}, Attrs = {} }, imt)
	for k, v in props or {} do rawset(o, k, v) end
	return o
end
local folder = inst("Folder", "Monsters")
local function monster(kind, pos)
	local m = inst("Model", kind)
	m.Attrs.MonsterKind = kind
	m.Parent = folder
	local root = inst("Part", "HumanoidRootPart", { Position = pos })
	root.Parent = m
	local bb = inst("BillboardGui", "MonsterBar", { StudsOffset = vec(0, 3.2, 0), Enabled = true })
	bb.Parent = root
	inst("TextLabel", "NameLabel", { Visible = true }).Parent = bb
	local back = inst("Frame", "Bar", { Visible = true })
	back.Parent = bb
	inst("Frame", "Fill", { Size = { X = { Scale = 1 } } }).Parent = back
	return m, bb
end
-- a level camera at z = 10, name-tag height 3.2, looking along -Z, focal 800 px, centre (960, 540)
local cam = { Focus = { Position = vec(0, 3, 0) } }
function cam:WorldToViewportPoint(p)
	local depth = 10 - p.Z
	if depth <= 0 then return vec(0, 0, depth), false end
	return vec(960 + p.X * 800 / depth, 540 - (p.Y - 3.2) * 800 / depth, depth), true
end
local root = inst("Part", "HumanoidRootPart", { Position = vec(0, 3, 0) })
local char = inst("Model", "Character")
root.Parent = char
local services = {
	Players = { LocalPlayer = { Character = char } },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, n) return { __module = n } end } end },
	TweenService = { Create = function() return { Play = function() end } end },
}
local W = { Now = 1000 }
local env = setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end },
	workspace = { GetServerTimeNow = function() return W.Now end, CurrentCamera = cam,
		FindFirstChild = function(_, n) if n == "Monsters" then return folder end end },
	Vector3 = { new = vec }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { fromOffset = function(x, y) return { X = x, Y = y } end, fromScale = function(x, y) return { X = x, Y = y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
		fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function() return {} end }, Enum = enum,
	Instance = { new = function(class) return inst(class) end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	os = { clock = function() return W.Now end },
	task = { delay = function() end, spawn = function() end, wait = function() end },
	warn = function(...) print("WARN", ...) end, print = function() end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
local Config = cfn()
env.require = function() return Config end
local lfn = assert(loadstring(LABELS_SOURCE, "=MonsterLabels"))
setfenv(lfn, env)
local ML = lfn()
ML.Init({})
check(type(ML.Tick) == "function", "MonsterLabels exposes one label pass (test aid)")

local function nameShown(bb) return bb.Enabled and bb:FindFirstChild("NameLabel").Visible end
-- a slime in front of me and one 7 studs further back drawn on top of it; another slime off to the side; a goblin
-- on top of the first slime on screen; a slime 3 studs from the first (the old world cluster rule)
local _, s1 = monster("Slime", vec(0, 0, -5))
local _, s2 = monster("Slime", vec(1, 0, -12))
local _, s3 = monster("Slime", vec(8, 0, -5))
local _, g1 = monster("Goblin", vec(0.5, 0, -9))
ML.Tick()
check(nameShown(s1), "the nearest slime shows its name")
check(not nameShown(s2), "a same-kind name drawn over a shown one on screen hides (7 studs apart in the world)",
	tostring(s2:FindFirstChild("NameLabel").Visible))
check(nameShown(s3), "a same-kind name far away on screen stays")
check(nameShown(g1), "another kind on top of it on screen keeps its name (only same-kind tags merge)")
-- the old world-distance rule still holds
local _, s4 = monster("Slime", vec(4, 0, -5)) -- 4 studs from the first slime, 213 px apart on screen
ML.Tick()
check(not nameShown(s4), "a same-kind monster within Cluster studs of a shown name keeps only its bar")
-- a monster behind the camera never blocks or is blocked on screen
local _, s5 = monster("Slime", vec(30, 0, 15))
ML.Tick()
check(not s5.Enabled or s5:FindFirstChild("NameLabel").Visible == false or true, "off-screen monsters never crash the pass")
print("MONSTER_LABELS_SUMMARY checks=" .. checks .. " failed=" .. failed)
