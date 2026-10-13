-- A23-156 (user 10/13): the private test server's switch, tools/test_test_server.py. The real Config.luau with engine
-- doubles (the same doubles as skill_kit_offline.luau); checks Config.TestServer and Config.ApplyTestServer().
-- Input: CONFIG_SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local ENUM
do
	local types = {}
	ENUM = setmetatable({}, { __index = function(_, typeName)
		local t = types[typeName]
		if not t then
			local cache = {}
			t = setmetatable({}, { __index = function(_, itemName)
				local e = cache[itemName]
				if not e then
					e = { Name = itemName, EnumType = typeName, __kind = "EnumItem" }
					cache[itemName] = e
				end
				return e
			end })
			types[typeName] = t
		end
		return t
	end })
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
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local env = setmetatable({ Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), CFrame = ctor("CFrame"),
	TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = ENUM }, { __index = getfenv() })
local function load()
	local f = assert(loadstring(CONFIG_SOURCE, "=Config"))
	setfenv(f, env)
	return f()
end

local Config = load()
local T = Config.TestServer
check(type(T) == "table" and T.Enabled == true and type(T.Skills) == "table" and T.Skills.ZEnabled == true and T.GooseEvery == 600
	and T.PassSales == true, "Config.TestServer: on, the Z skill, a goose every 600 s, pass sales (A23-156)",
	T and { T.Enabled, T.GooseEvery, T.PassSales })
local skillKeys = {}
for k in (T and T.Skills) or {} do table.insert(skillKeys, k) end
check(#skillKeys == 1 and skillKeys[1] == "ZEnabled", "only the Z skill is turned on (XEnabled / PvPZX untouched)", table.concat(skillKeys, ","))
check(type(Config.ApplyTestServer) == "function", "Config.ApplyTestServer exists", type(Config.ApplyTestServer))

local S, G, P = Config.Skills, Config.Goose, Config.Switches.Defs.PassSales
check(S.ZEnabled == false and S.XEnabled == false and S.PvPZX == false and G.Schedule.Every == 14400 and G.Schedule.TzOffset == 32400
	and P.Default == true, "before ApplyTestServer: the real defaults (Z off, every 4 h on the KST clock, sales on)",
	{ S.ZEnabled, G.Schedule.Every, P.Default })
check(Config.ApplyTestServer() == true, "ApplyTestServer applies once")
check(S.ZEnabled == true and S.XEnabled == false and S.PvPZX == false, "after: Z on; X and Z-on-players stay off",
	{ S.ZEnabled, S.XEnabled, S.PvPZX })
check(G.Schedule.Every == 600 and G.Schedule.TzOffset == 32400 and G.Interval == 600 and G.Duration == 60,
	"after: the goose every 600 s on the clock; the KST offset, the tug interval and the length unchanged", G.Schedule.Every)
check(P.Default == true, "after: pass sales on", P.Default)
S.ZEnabled = false
check(Config.ApplyTestServer() == false and S.ZEnabled == false and G.Schedule.Every == 600, "a second call does nothing", S.ZEnabled)

-- switched off: one line, the real rules
local off = load()
off.TestServer.Enabled = false
check(off.ApplyTestServer() == false and off.Skills.ZEnabled == false and off.Goose.Schedule.Every == 14400
	and off.Switches.Defs.PassSales.Default == true, "Enabled = false: nothing changes", { off.Skills.ZEnabled, off.Goose.Schedule.Every })

-- the sales value is the table's
local noSale = load()
noSale.TestServer.PassSales = false
noSale.ApplyTestServer()
check(noSale.Switches.Defs.PassSales.Default == false and noSale.Skills.ZEnabled == true, "PassSales = false turns the default sales off",
	noSale.Switches.Defs.PassSales.Default)

-- the Z skill's own numbers are unchanged (Lv15, the key X): the test server only opens it
check(Config.Skills.Unlock.Z == 15, "the Z skill still opens at Lv15", Config.Skills.Unlock.Z)

print("TEST_SERVER_SUMMARY checks=" .. checks .. " failed=" .. failed)
