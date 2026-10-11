-- 걷는 바닥 (게임성 개발 1, 2026-10-11): runs the real Config.luau (Config.GroundRoots) and the real Shared Ground.luau
-- (tools/test_ground_rays.py) on doubles: a map tree, CollectionService (tagged list + added / removed signals),
-- workspace (Terrain, Map, Raycast recording), RaycastParams, os.clock. Inputs: CONFIG_SOURCE, GROUND_SOURCE.
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
vmt.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, vmt) end
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()

local function node(name, kids)
	local o = { Name = name, Kids = kids or {} }
	function o.GetChildren(self) return self.Kids end
	function o.FindFirstChild(self, n) for _, k in self.Kids do if k.Name == n then return k end end return nil end
	return o
end
local function names(list)
	local set, n = {}, 0
	for _, i in list do
		set[i.Name] = (set[i.Name] or 0) + 1
		n += 1
	end
	return set, n
end

-- 1. Config.GroundRoots (pure)
local terrain = node("Terrain")
local arch = node("Halo_ArchBridge_1")
local tree = node("Halo_Tree_3")
local cellBridge = node("Cell_Bridge_2")
local oldBridge = node("Bridge_Halo")
local lamp = node("Lamp_1")
local groundF = node("Ground")
local floor = node("HaloHouse07_Floor")
local yard = node("Yard_1")
local stairs = node("Halo_Stairs") -- 게임성 검수 10/13 (e27_stairs)
local map = node("Map", {
	groundF,
	node("Decor", { oldBridge, lamp, node("HaloProps", { node("Cell_1", { tree, arch, floor, stairs }), cellBridge }) }),
})
check(Config.Ground and Config.Ground.Tag == "WalkGround", "the tag is WalkGround (server and client agree)", Config.Ground and Config.Ground.Tag)
local set, n = names(Config.GroundRoots(terrain, map, nil))
check(set.Terrain and set.Ground and set.Bridge_Halo, "Terrain, Map.Ground and Decor Bridge_* are ground", "")
check(set.Halo_ArchBridge_1, "the kit's arch bridge (HaloProps.Cell_*.Halo_ArchBridge_*) is ground", "")
check(set.Cell_Bridge_2, "a kit cell that is itself a bridge is ground", "")
check(set.Halo_Stairs, "10/13: the kit's stairs (HaloProps.Cell_*.Halo_Stairs) are ground (the staff stood 2..3 studs over them)", "")
check(not set.Halo_Tree_3 and not set.Lamp_1 and not set.HaloProps and not set.Cell_1 and not set.HaloHouse07_Floor,
	"other props, folders and untagged floors are not ground", "")
set, n = names(Config.GroundRoots(terrain, map, { floor, yard }))
check(set.HaloHouse07_Floor == 1 and set.Yard_1 == 1, "parts tagged WalkGround are ground (a house floor, a yard)", "")
set, n = names(Config.GroundRoots(terrain, map, { oldBridge, floor, floor }))
check(set.Bridge_Halo == 1 and set.HaloHouse07_Floor == 1, "a tagged bridge or a twice-listed part is listed once", "")
set, n = names(Config.GroundRoots(terrain, nil, { yard }))
check(n == 2 and set.Terrain and set.Yard_1, "no map: Terrain + the tagged parts", n)

-- 2. Shared Ground (the cached params)
local CLOCK = 10
local tagged = {}
local tagCalls = 0
local sig = { Added = {}, Removed = {} }
local CS = {
	GetTagged = function(_, tag)
		tagCalls += 1
		return tag == "WalkGround" and table.clone(tagged) or {}
	end,
	GetInstanceAddedSignal = function(_, tag)
		return { Connect = function(_, f) if tag == "WalkGround" then table.insert(sig.Added, f) end end }
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return { Connect = function(_, f) if tag == "WalkGround" then table.insert(sig.Removed, f) end end }
	end,
}
local casts = {}
local ws = { Terrain = terrain, Map = map }
function ws.FindFirstChild(_, n) return n == "Map" and ws.Map or nil end
function ws.Raycast(_, origin, dir, params)
	table.insert(casts, { Origin = origin, Dir = dir, Params = params })
	return { Position = origin }
end
local genv = setmetatable(table.clone(base), { __index = getfenv() })
genv.game = { GetService = function(_, n) if n == "CollectionService" then return CS end return nil end }
genv.script = { Parent = { WaitForChild = function(_, n) return n end } }
genv.require = function(n) if n == "Config" then return Config end return nil end
genv.workspace = ws
genv.os = { clock = function() return CLOCK end }
genv.RaycastParams = { new = function() return {} end }
local gf = assert(loadstring(GROUND_SOURCE, "=Ground"))
setfenv(gf, genv)
local Ground = gf()

local function has(params, name)
	for _, i in params.FilterDescendantsInstances or {} do if i.Name == name then return true end end
	return false
end
local p = Ground.Params()
check(p.FilterType == "RaycastFilterType.Include", "an Include filter", p.FilterType)
check(p.IgnoreWater == false, "water is not ignored (a hit on the sea says Water)", p.IgnoreWater)
check(has(p, "Terrain") and has(p, "Ground") and has(p, "Halo_ArchBridge_1") and not has(p, "Halo_Tree_3"),
	"the params follow Config.GroundRoots", "")
local before = tagCalls
Ground.Params()
Ground.Params()
check(tagCalls == before, "cached between calls (no rebuild every ray)", tagCalls - before)
tagged = { floor }
check(#sig.Added == 1 and #sig.Removed == 1, "it listens to the tag being added / removed", #sig.Added)
for _, f in sig.Added do f(floor) end
p = Ground.Params()
check(has(p, "HaloHouse07_Floor"), "a newly tagged floor counts at once", "")
tagged = {}
for _, f in sig.Removed do f(floor) end
p = Ground.Params()
check(not has(p, "HaloHouse07_Floor"), "an untagged floor stops counting at once", "")
local newMap = node("Map", { node("Ground"), node("Decor", { node("Bridge_Horns") }) })
ws.Map = newMap
p = Ground.Params()
check(has(p, "Bridge_Horns") and not has(p, "Bridge_Halo"), "a new Map is picked up at once", "")
ws.Map.Kids[2].Kids[2] = node("Bridge_Late")
p = Ground.Params()
check(not has(p, "Bridge_Late"), "inside the refresh time the list stays", "")
CLOCK += (Config.Ground.Refresh or 5) + 0.1
p = Ground.Params()
check(has(p, "Bridge_Late"), "after Refresh s a late MapBuilder bridge is picked up", "")
table.clear(casts)
local hit = Ground.Cast(vec(1, 10, 2), 6, 80)
local c = casts[1]
check(c and c.Origin.Y == 16 and c.Origin.X == 1 and c.Dir.Y == -80 and c.Params == p and hit ~= nil,
	"Cast(pos, 6, 80) = from 6 above, 80 down, the ground params", c and c.Origin.Y)
table.clear(casts)
Ground.Cast(vec(0, 0, 0))
check(casts[1] and casts[1].Origin.Y == 3 and casts[1].Dir.Y == -80, "Cast defaults: 3 up, 80 down", casts[1] and casts[1].Origin.Y)

print(("RAYS_SUMMARY checks=%d failed=%d"):format(checks, failed))
