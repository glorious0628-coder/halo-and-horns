-- LightCap (게임성 개발 1, 빛 마을 점검 #61): runs the real LightCap.luau (tools/test_light_cap.py) on doubles: players with
-- characters holding PointLights, a camera. Input: CAP_SOURCE. Every check is named and counted.
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
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vmt) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end return nil end
local function light(on)
	local l = { ClassName = "PointLight", Enabled = on ~= false }
	function l.IsA(self, c) return c == self.ClassName end
	return l
end
local function player(id, x)
	local root = { Position = vec(x, 3, 0) }
	local lights = { light(), light() }
	local char = { Root = root, Lights = lights }
	function char.FindFirstChild(_, n) if n == "HumanoidRootPart" then return root end return nil end
	function char.GetDescendants() return lights end
	return { UserId = id, Character = char }
end
local ME = player(1, 0)
local LIST = { ME }
for i = 1, 9 do table.insert(LIST, player(100 + i, i * 10)) end
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = ME, GetPlayers = function() return LIST end } end
		return {}
	end },
	workspace = { CurrentCamera = { CFrame = { Position = vec(0, 3, 0) } } },
	task = { spawn = function() end, wait = function() end },
}, { __index = getfenv() })
local f = assert(loadstring(CAP_SOURCE, "=LightCap"))
setfenv(f, env)
local LC = f()

local k = LC.Keep({ { Key = "a", D = 5 }, { Key = "b", D = 1 }, { Key = "c", D = 9 } }, 2)
check(k.a and k.b and not k.c, "Keep: the nearest `max`")
local function lit(p) return p.Character.Lights[1].Enabled and p.Character.Lights[2].Enabled end
LIST[8].Character.Lights[2].Enabled = false -- the server turned this one off itself (the 7th nearest player)
LC.Pass()
local near6 = true
for i = 2, 7 do if not lit(LIST[i]) then near6 = false end end
check(near6, "the nearest 6 other characters keep their lights")
check(not LIST[8].Character.Lights[1].Enabled and not LIST[9].Character.Lights[1].Enabled and not LIST[10].Character.Lights[1].Enabled,
	"the 7th, 8th and 9th are dark on this screen")
check(lit(ME), "my own lights are never touched")
-- the far ones come close: the near ones go far
for i = 2, 10 do LIST[i].Character.Root.Position = vec(110 - (i - 1) * 10, 3, 0) end
LC.Pass()
check(LIST[8].Character.Lights[1].Enabled == true and LIST[8].Character.Lights[2].Enabled == false,
	"coming near: the lights this module turned off come back, a light the server turned off stays off")
check(not LIST[2].Character.Lights[1].Enabled, "going far: the old nearest one goes dark")
print(("LIGHT_CAP_SUMMARY checks=%d failed=%d"):format(checks, failed))
