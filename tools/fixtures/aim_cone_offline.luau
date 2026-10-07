-- A23-61 (user 2026-10-06 night): the basic attack hits the whole front half (90 deg left / right of where I face, 180 in
-- all), nothing behind; every class and bare hands; the SKL skill cones are not part of it. Runs the real Config.luau
-- (class rows, Combat.Unarmed, AttackProfile, Skills.Defs) and CombatService's real inAim (cut out by the runner,
-- tools/test_aim_cone.py) with small doubles. Inputs: CONFIG_SOURCE, INAIM_SOURCE. Every check is named and counted.
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
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	return nil
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local env = setmetatable({ Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum, workspace = { GetServerTimeNow = function() return 1790000000 end } }, { __index = getfenv() })
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, env)
local Config = fn()
local cut = assert(loadstring(INAIM_SOURCE .. "\nreturn inAim", "=inAim"))
setfenv(cut, env)
local inAim = cut()

-- the root at the origin, looking along -Z; a target `deg` degrees off my facing (to my right for +, left for -), 6 studs
local root = { Position = vec(0, 3, 0), CFrame = { LookVector = vec(0, 0, -1) } }
local function at(deg)
	local r = math.rad(deg)
	return vec(6 * math.sin(r), 3, -6 * math.cos(r))
end

-- 1. the numbers: every class row, the punch, every AttackProfile (armed / bare, Halo / Horns / the tamer)
for _, id in Config.ClassOrder do
	check(Config.Classes[id].AimCone == 90, id .. " class row AimCone = 90 (the front half)", Config.Classes[id].AimCone)
end
check(Config.Combat.Unarmed.AimCone == 90, "bare hands AimCone = 90", Config.Combat.Unarmed.AimCone)
for _, id in Config.ClassOrder do
	for _, tier in { 0, 1, 8 } do
		for _, f in { "Halo", "Horns", "Neutral" } do
			local p = Config.AttackProfile(id, tier, f)
			check(p and p.AimCone == 90, "AttackProfile AimCone = 90 for every class / weapon / side (tamer too)",
				id .. " tier " .. tier .. " " .. f .. " " .. tostring(p and p.AimCone))
		end
	end
end
-- 2. the SKL skill cones are not part of A23-61
local defs = Config.Skills and Config.Skills.Defs
check(defs and defs.Warrior.Z.AimCone == 75 and defs.Blacksmith.Z.AimCone == 75, "skill cones stay (Earth Cleave / Hook Chain 75)",
	defs and defs.Warrior.Z.AimCone)

-- 3. what the server's inAim lets a swing hit with that cone
for _, id in Config.ClassOrder do
	for _, tier in { 0, 1 } do
		local cone = Config.AttackProfile(id, tier, "Halo").AimCone
		local tag = id .. (tier == 0 and " bare" or " armed")
		check(inAim(root, at(0), cone) and inAim(root, at(45), cone) and inAim(root, at(-45), cone), tag .. ": in front -> hit")
		check(inAim(root, at(85), cone) and inAim(root, at(-85), cone) and inAim(root, at(89.5), cone) and inAim(root, at(-89.5), cone),
			tag .. ": right beside me (85-89.5 deg, both sides) -> hit (A23-61)")
		check(not inAim(root, at(95), cone) and not inAim(root, at(-95), cone) and not inAim(root, at(135), cone)
			and not inAim(root, at(180), cone), tag .. ": behind the side line (95 deg+) / behind me -> never hit")
		check(inAim(root, vec(0.3, 3, 0.4), cone), tag .. ": a target on top of me (under 1 stud) -> hit")
	end
end

print("AIM_CONE_SUMMARY checks=" .. checks .. " failed=" .. failed)
