-- PvP rope (게임성 개발 1; A23-90 "경계에 잘 보이는 표시", 검수 2026-10-09 "빨강·흰 줄 + 작은 깃발, 빛 없음"): runs the
-- real Config.luau and the real PvPRope.luau (tools/test_pvp_rope.py) on small doubles: Instance.new records every
-- part, workspace:Raycast returns a ground height, a character to walk near the lines, a fake task loop.
-- Inputs: CONFIG_SOURCE, ROPE_SOURCE. Every check is named and counted.
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
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end
	return nil
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function typeof2(v)
	if type(v) == "table" and v.__kind then return v.__kind end
	return typeof(v)
end
local cfm = {}
local CF = setmetatable({
	new = function(x, y, z) return setmetatable({ Position = vec(x, y, z) }, cfm) end,
	lookAt = function(p, q) return setmetatable({ Position = p, Look = q }, cfm) end,
	Angles = function() return setmetatable({ Position = vec(0, 0, 0) }, cfm) end,
}, {})
cfm.__mul = function(a, _) return a end
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = function(r, g, b) return setmetatable({ X = r, Y = g, Z = b, __kind = "Color3" }, vmt) end,
		fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = CF, TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum, typeof = typeof2 }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.CFrame = ctor("CFrame")
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()
local R = Config.PvPRope

-- doubles
local made = {}
local GROUND = 1.5
local rays = 0
local workspace = { Terrain = { Name = "Terrain" }, Children = {} }
function workspace.FindFirstChild(_, n)
	for _, c in made do if c.Name == n and c.Parent == workspace then return c end end
	return nil
end
function workspace.Raycast(_, origin, dir, params)
	rays += 1
	return { Position = vec(origin.X, GROUND, origin.Z) }
end
local Instance = { new = function(c)
	local o = { ClassName = c }
	table.insert(made, o)
	return o
end }
local root = { Position = vec(0, 3, 0) }
local char = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end return nil end }
local player = { Character = char }
local loops = {}
local Util = {
	Warn = function(...) print("WARN", ...) end,
	FlatDistance = function(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end,
}
local shared = { WaitForChild = function(_, n) return n end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return { WaitForChild = function() return shared end } end
	return nil
end }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance, env.workspace = game, Instance, workspace
env.require = function(n) if n == "Config" then return Config end return Util end
env.RaycastParams = { new = function() return {} end }
env.task = { spawn = function(f) table.insert(loops, coroutine.create(f)) end, wait = function() coroutine.yield() end }
local rf = assert(loadstring(ROPE_SOURCE, "=PvPRope"))
setfenv(rf, env)
local PvPRope = rf()
local function pump(n)
	for _ = 1, n or 1 do
		for _, co in loops do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then print("LOOP_ERROR " .. tostring(err)) end
			end
		end
	end
end
local function count(cls, name, color)
	local n = 0
	for _, o in made do
		if o.ClassName == cls and (name == nil or o.Name == name) and (color == nil or o.Color == color) then n += 1 end
	end
	return n
end

-- 0. the numbers: red / white stripes, small flags, no light
check(R ~= nil and R.Enabled ~= false, "Config.PvPRope is on")
check(R.Red.X > 150 and R.Red.Y < 90 and R.White.X > 230 and R.White.Y > 230, "red and white", tostring(R.Red.X))
check(R.FlagSize.Y <= 1.5 and R.FlagSize.Z <= 2, "the flags are small", tostring(R.FlagSize.Y))
check(R.PostHeight <= 4 and R.RopeHeight < R.PostHeight, "knee-high posts, the rope under their tops")

-- 1. pure: the lines and the Crown Pit
local segs = PvPRope.Segments(R, Config.Zones)
local byGroup = {}
for _, s in segs do
	byGroup[s.Group] = (byGroup[s.Group] or 0) + 1
end
check(byGroup.Line1 ~= nil and byGroup.Line2 ~= nil, "both Goblin Woods edges have a rope (meadow bridge, ruins pass)",
	tostring(byGroup.Line1) .. " " .. tostring(byGroup.Line2))
check(byGroup.Area_SkeletonRuins ~= nil, "the ruins' Crown Pit (PvPArea) has a rope round it", byGroup.Area_SkeletonRuins)
check(byGroup.Area_GoblinWoods == nil, "a whole-PvP zone has no area rope (its edges are lines)")
local pit = Config.Zones.SkeletonRuins.PvPArea
local onEdge, inside, openings = true, 0, 0
for _, s in segs do
	if s.Group == "Area_SkeletonRuins" then
		for _, p in s.Posts do
			local dx, dz = math.abs(p.X - pit.Center.X), math.abs(p.Z - pit.Center.Z)
			local edge = math.abs(dx - pit.Size.X / 2) < 1e-6 or math.abs(dz - pit.Size.Z / 2) < 1e-6
			if not edge then onEdge = false end
			if dx < pit.Size.X / 2 - 1e-6 and dz < pit.Size.Z / 2 - 1e-6 then inside += 1 end
		end
	end
end
check(onEdge and inside == 0, "every pit post stands on the pit's edge", inside)
local pitRuns = byGroup.Area_SkeletonRuins or 0
check(pitRuns == 8, "an opening in the middle of each of the 4 sides (8 runs)", pitRuns)
-- line 1: the road (|z| < 10) stays open, posts at most PostGap apart, flags at both ends of each run
local roadPost, maxGap, endsFlagged = false, 0, true
for _, s in segs do
	if s.Group == "Line1" then
		for i, p in s.Posts do
			if math.abs(p.Z) < 10 then roadPost = true end
			if i > 1 then maxGap = math.max(maxGap, Util.FlatDistance(p, s.Posts[i - 1])) end
		end
		if not (s.Flags[1] and s.Flags[#s.Posts]) then endsFlagged = false end
	end
end
check(not roadPost, "the road through the bridge end stays open (no post on it)")
check(maxGap <= R.PostGap + 1e-6, "posts at most PostGap apart", maxGap)
check(endsFlagged, "a flag on the posts at each opening / end")
local x1 = nil
for _, s in segs do if s.Group == "Line1" then x1 = s.Posts[1].X end end
local woods = Config.Zones.GoblinWoods
check(x1 ~= nil and x1 >= woods.Center.X - woods.Size.X / 2 and x1 - (woods.Center.X - woods.Size.X / 2) <= 4,
	"the meadow-side rope stands just inside the woods' edge (where PvP starts)", x1)
local noAreas = table.clone(R)
noAreas.Areas = false
local only = PvPRope.Segments(noAreas, Config.Zones)
local anyArea = false
for _, s in only do if string.sub(s.Group, 1, 5) == "Area_" then anyArea = true end end
check(not anyArea, "Areas = false: no area ropes")

-- 2. built only near me, on the ground, no light, nothing collides
PvPRope.Start()
pump(1)
check(PvPRope.Built() == 0 and count("Part", "Post") == 0, "far away (the Crossroads): nothing built yet", PvPRope.Built())
root.Position = vec(700, 3, 0)
pump(1)
check(PvPRope.Built() == 1, "near the bridge end: that rope is built", PvPRope.Built())
local posts, ropes, flags = count("Part", "Post"), count("Part", "Rope"), count("WedgePart", "Flag")
check(posts > 10 and ropes > posts and flags >= 4, "posts, rope stripes and flags", posts .. " " .. ropes .. " " .. flags)
local neon, solid, stripesOk, postOnGround = false, false, true, true
local reds, whites = count("Part", "Rope", R.Red), count("Part", "Rope", R.White)
for _, o in made do
	if o.ClassName == "Part" or o.ClassName == "WedgePart" then
		if o.Material == "Material.Neon" or o.Material == "Material.ForceField" then neon = true end
		if o.CanCollide ~= false or o.CanTouch ~= false or o.CanQuery ~= false or o.CastShadow ~= false or o.Anchored ~= true then solid = true end
		if o.Name == "Post" and math.abs(o.CFrame.Position.Y - (GROUND + o.Size.Y / 2)) > 1e-6 then postOnGround = false end
	end
end
check(not neon, "no Neon / glow anywhere")
check(not solid, "nothing collides, is touched, is queried or casts a shadow (all anchored)")
check(reds > 0 and whites > 0 and math.abs(reds - whites) <= #segs, "red and white stripes take turns", reds .. "/" .. whites)
check(postOnGround, "posts stand on the ground under them (one ray each)")
local flagRed = true
for _, o in made do if o.ClassName == "WedgePart" and o.Color ~= R.Red then flagRed = false end end
check(flagRed, "the flags are red")
local folderOk = workspace:FindFirstChild("ClientPvPRope") ~= nil
check(folderOk, "everything sits in the client folder ClientPvPRope")
local before = #made
pump(3)
check(#made == before, "built once (no rebuild while I stay)", #made - before)
root.Position = vec(1225, 3, 0)
pump(1)
check(PvPRope.Built() == 2, "in the pass: the woods' ruins-side rope", PvPRope.Built())
root.Position = vec(1660, 3, 0)
pump(1)
check(PvPRope.Built() == 3, "at the Crown Pit: its rope", PvPRope.Built())
local after = #made
pump(2)
check(#made == after, "everything built: the loop stops building", #made - after)

print(("PVP_ROPE_SUMMARY checks=%d failed=%d"):format(checks, failed))
