-- Offline checks for the monster bark bubble (MonsterLabels, lines_pack 2 / dev2 BarkService contract): the real
-- MonsterLabels.luau + Config.luau with small doubles; MonsterLabels.Bark.Check runs per monster per tick.
-- Inputs: CONFIG_SOURCE, LABELS_SOURCE. No Studio / Roblox API calls.
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

-- instances: properties, Children, Parent, FindFirstChild, Destroy, IsA
local imt = {}
imt.__index = {
	FindFirstChild = function(self, n)
		for _, ch in self.Children do if ch.Name == n then return ch end end
		return nil
	end,
	IsA = function(self, c) return self.ClassName == c end,
	Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then
			for i, ch in p.Children do if ch == self then table.remove(p.Children, i) break end end
		end
		rawset(self, "Parent", nil)
		rawset(self, "Destroyed", true)
	end,
	GetAttribute = function(self, k) return self.Attrs[k] end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "Parent")
		if old then for i, ch in old.Children do if ch == self then table.remove(old.Children, i) break end end end
		rawset(self, "Parent", v)
		if v then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class, name)
	return setmetatable({ ClassName = class, Name = name or class, Children = {}, Attrs = {} }, imt)
end

local W = { Now = 1000, Timers = {} }
local function advance(dt)
	W.Now += dt
	local due = {}
	for i = #W.Timers, 1, -1 do
		if W.Timers[i].At <= W.Now then table.insert(due, table.remove(W.Timers, i)) end
	end
	table.sort(due, function(a, b) return a.At < b.At end)
	for _, t in due do t.Fn() end
end
local kitArt = true
local kit = {
	ArtImage = function(name, props)
		if not kitArt or name ~= "BarkBubble" then return nil end
		local img = inst("ImageLabel", props.Name)
		img.Size = props.Size
		return img
	end,
	ReducedMotion = function() return false end,
	Theme = { FontFace = nil },
}
local services = {
	Players = { LocalPlayer = { Character = nil } },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, n) return { __module = n } end } end },
	TweenService = { Create = function() return { Play = function() end } end },
}
local env = setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end },
	workspace = { GetServerTimeNow = function() return W.Now end, FindFirstChild = function() return nil end, CurrentCamera = nil },
	Vector3 = { new = vec }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { fromOffset = function(x, y) return { Kind = "Offset", X = x, Y = y } end,
		fromScale = function(x, y) return { Kind = "Scale", X = x, Y = y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
		fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function() return {} end }, Enum = enum,
	Instance = { new = function(class) return inst(class) end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	task = { delay = function(t, fn) table.insert(W.Timers, { At = W.Now + t, Fn = fn }) end, spawn = function() end, wait = function() end },
	warn = function(...) print("WARN", ...) end, print = function() end,
	require = function(m) return m.__config end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
local Config = cfn()
env.require = function() return Config end
local lfn = assert(loadstring(LABELS_SOURCE, "=MonsterLabels"))
setfenv(lfn, env)
local ML = lfn()
ML.Init({ UIKit = kit })
local B = ML.Bark
check(type(B) == "table" and type(B.Check) == "function", "MonsterLabels exposes the bark check (test aid)")

local function monster(pos)
	local m = inst("Model", "Slime")
	local root = inst("Part", "HumanoidRootPart")
	root.Position = pos
	root.Parent = m
	local bar = inst("BillboardGui", "MonsterBar")
	bar.StudsOffset = vec(0, 3.2, 0)
	bar.Parent = root
	return m, root, bar
end
local me = vec(0, 3, 0)
local function bubbleOf(root) return root:FindFirstChild("BarkBubble") end
local function lineOf(root)
	local bb = bubbleOf(root)
	local art = bb and bb:FindFirstChild("Art")
	return art and art:FindFirstChild("Line")
end

-- 1. a new bark near me: one bubble over the head, the line, size / offset / range
local m, root, bar = monster(vec(10, 3, 0))
B.Check(m, root, bar, me)
check(bubbleOf(root) == nil, "no bark yet -> no bubble")
m.Attrs.Bark, m.Attrs.BarkAt = "Blub?", W.Now
B.Check(m, root, bar, me)
local bb = bubbleOf(root)
check(bb ~= nil and lineOf(root) and lineOf(root).Text == "Blub?", "a new BarkAt shows Bark in a bubble over the head", bb and lineOf(root) and lineOf(root).Text)
check(bb and bb.MaxDistance == Config.Barks.MaxDistance and bb.SizeOffset.X == 0.5 and bb.SizeOffset.Y == 0.5
	and math.abs(bb.StudsOffset.Y - (3.2 + 1.1)) < 1e-6 and bb.AlwaysOnTop == false,
	"bubble: MaxDistance from Config.Barks, tail corner at the head (SizeOffset 0.5), above the name tag",
	bb and tostring(bb.MaxDistance))
check(bb and bb:FindFirstChild("Art") and bb:FindFirstChild("Art").ClassName == "ImageLabel", "the BarkBubble art draws the bubble")
local rect = Config.UIArt.Parts.BarkBubble.TextRect
local line = lineOf(root)
check(line and line.Position.X == rect[1] and line.Position.Y == rect[2] and line.Size.X == rect[3] and line.Size.Y == rect[4]
	and line.TextWrapped and line.TextScaled, "the line sits in the art's TextRect, wrapped and scaled")
-- 2. the same BarkAt again: nothing new
B.Check(m, root, bar, me)
check(bubbleOf(root) == bb and not bb.Destroyed, "the same BarkAt on the next tick: no new bubble")
-- 3. the same line with a new BarkAt: a new bubble (the server bumps BarkAt even for the same words)
advance(1)
m.Attrs.BarkAt = W.Now
B.Check(m, root, bar, me)
local bb2 = bubbleOf(root)
local count = 0
for _, ch in root.Children do if ch.Name == "BarkBubble" then count += 1 end end
check(bb2 ~= nil and bb2 ~= bb and bb.Destroyed == true and count == 1, "the same line with a new BarkAt shows again (one bubble)", count)
-- 4. the older timer never removes the newer bubble; the newer one goes after Show seconds
advance(Config.Barks.Show - 1 + 0.01)
check(bubbleOf(root) == bb2, "the first bubble's timer leaves the newer bubble")
advance(1)
check(bubbleOf(root) == nil, "the bubble goes after Config.Barks.Show seconds")
-- 5. an old bark when a monster streams in: not shown
local m2, root2, bar2 = monster(vec(5, 3, 0))
m2.Attrs.Bark, m2.Attrs.BarkAt = "Grr!", W.Now - Config.Barks.Show - 1
B.Check(m2, root2, bar2, me)
check(bubbleOf(root2) == nil, "a bark already old when the monster streams in is not shown")
m2.Attrs.BarkAt = W.Now
B.Check(m2, root2, bar2, me)
check(bubbleOf(root2) ~= nil, "its next bark shows")
-- 6. too far / switched off / empty line
local m3, root3, bar3 = monster(vec(Config.Barks.MaxDistance + 5, 3, 0))
B.Check(m3, root3, bar3, me)
m3.Attrs.Bark, m3.Attrs.BarkAt = "Far away", W.Now
B.Check(m3, root3, bar3, me)
check(bubbleOf(root3) == nil, "a monster farther than Config.Barks.MaxDistance: no bubble")
local m4, root4, bar4 = monster(vec(8, 3, 0))
B.Check(m4, root4, bar4, me)
Config.Barks.Enabled = false
m4.Attrs.Bark, m4.Attrs.BarkAt = "Off", W.Now
B.Check(m4, root4, bar4, me)
check(bubbleOf(root4) == nil, "Config.Barks.Enabled = false: no bubble")
Config.Barks.Enabled = true
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "", W.Now
B.Check(m4, root4, bar4, me)
check(bubbleOf(root4) == nil, "an empty line: no bubble")
-- 7. long lines get a taller bubble; no art -> the white box with a navy rim
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Wobbly... so wobbly... blub.", W.Now
B.Check(m4, root4, bar4, me)
local b4 = bubbleOf(root4)
check(b4 and b4.Size.Y == B.H2 and b4.Size.X == B.W, "a long line gets the taller bubble", b4 and b4.Size.Y)
kitArt = false
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub!", W.Now
B.Check(m4, root4, bar4, me)
local b5 = bubbleOf(root4)
local art5 = b5 and b5:FindFirstChild("Art")
check(art5 and art5.ClassName == "Frame" and art5:FindFirstChild("UIStroke") and art5:FindFirstChild("UICorner")
	and art5:FindFirstChild("Line"), "without the art: a white rounded box with a rim (code fallback)")
print("MONSTER_BARK_SUMMARY checks=" .. checks .. " failed=" .. failed)
