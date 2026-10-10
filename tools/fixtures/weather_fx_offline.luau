-- WeatherFx (이미지 개발 2026-10-10, A23-105): runs the real WeatherFx.luau (tools/test_weather_fx.py) on doubles:
-- services, Instance.new recording every object, a GameState with attributes, tagged / marked lamps, a camera and a
-- raycast that can hit a roof. Input: WX_SOURCE. Every check is named and counted.
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

local function signal()
	local s = { fns = {} }
	function s.Connect(_, fn) table.insert(s.fns, fn) return { Disconnect = function() end } end
	function s.Fire(_, ...) for _, fn in s.fns do fn(...) end end
	return s
end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	return nil
end
local Vector3 = { new = vec, zero = vec(0, 0, 0) }
local cmt = {}
cmt.__index = function(c, k)
	if k == "Lerp" then
		return function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t,
			B = a.B + (b.B - a.B) * t }, cmt) end
	end
	return nil
end
local Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, cmt) end }
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id)
		if id == "Value" then return 200 end
		return setmetatable({ Name = kind .. "." .. id, Value = 200 }, { __tostring = function() return kind .. "." .. id end })
	end })
end })

local LIGHTS = { PointLight = true, SpotLight = true, SurfaceLight = true }
local made = {}
local function obj(c, name)
	local o = { ClassName = c, Name = name or c, Children = {}, Attrs = {}, Tags = {} }
	function o.IsA(_, k)
		if k == c then return true end
		if k == "Light" then return LIGHTS[c] == true end
		if k == "BasePart" then return c == "Part" end
		return false
	end
	function o.GetAttribute(self, a) return self.Attrs[a] end
	function o.GetDescendants(self)
		local out = {}
		for _, ch in self.Children do
			table.insert(out, ch)
			for _, d in ch:GetDescendants() do table.insert(out, d) end
		end
		return out
	end
	function o.FindFirstChild(self, n)
		for _, ch in self.Children do if ch.Name == n then return ch end end
		return nil
	end
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

-- the world: a tagged street lamp light, a lantern model marked by attribute with a light inside, an unmarked light
local workspaceObj = obj("Workspace", "Workspace")
local lampLight = obj("PointLight", "StreetLampLight")
lampLight.Enabled = false
lampLight.Tags.LampLight = true
lampLight.Parent = workspaceObj
local lantern = obj("Model", "Lantern")
lantern.Attrs.LampLight = true
lantern.Parent = workspaceObj
local lanternBulb = obj("Part", "Bulb")
lanternBulb.Parent = lantern
local lanternLight = obj("SpotLight", "LanternLight")
lanternLight.Enabled = false
lanternLight.Parent = lanternBulb
local plainLight = obj("PointLight", "ShopWindowLight")
plainLight.Enabled = true
plainLight.Parent = workspaceObj

local camera = obj("Camera", "Camera")
camera.CFrame = { Position = vec(10, 5, 20), LookVector = vec(0, 0, -1) }
local roofHit = nil
local descAdded, tagAdded = signal(), signal()
workspaceObj.CurrentCamera = camera
workspaceObj.DescendantAdded = descAdded
function workspaceObj.Raycast(_, origin, dir) return roofHit end

local gs = obj("Folder", "GameState")
local gsSignals = {}
function gs.GetAttributeChangedSignal(_, a)
	gsSignals[a] = gsSignals[a] or signal()
	return gsSignals[a]
end
local function setState(a, v)
	gs.Attrs[a] = v
	if gsSignals[a] then gsSignals[a]:Fire() end
end
gs.Attrs.Weather, gs.Attrs.DayPhase = "Rain", "Night"

local lighting = obj("Lighting", "Lighting")
local touch = { TouchEnabled = false }
local render = {}
local clock = 100
local lp = obj("Player", "LocalPlayer")
function lp.GetAttributeChangedSignal() return signal() end
local services = {
	Players = { LocalPlayer = lp },
	Lighting = lighting,
	RunService = { IsStudio = function() return false end,
		BindToRenderStep = function(_, name, prio, fn) render.name, render.fn = name, fn end },
	ReplicatedStorage = { FindFirstChild = function(_, n) return n == "GameState" and gs or nil end,
		WaitForChild = function(_, n) return n == "GameState" and gs or nil end },
	CollectionService = {
		HasTag = function(_, inst, tag) return inst.Tags and inst.Tags[tag] == true end,
		GetTagged = function(_, tag)
			local out = {}
			for _, d in workspaceObj:GetDescendants() do if d.Tags[tag] then table.insert(out, d) end end
			return out
		end,
		GetInstanceAddedSignal = function() return tagAdded end,
	},
	UserInputService = touch,
}
local env = setmetatable({
	game = { GetService = function(_, n) return services[n] or {} end },
	workspace = workspaceObj, Instance = Instance, Vector3 = Vector3, Vector2 = { new = vec },
	CFrame = { new = function(p) return { Position = p } end }, Color3 = Color3, Enum = enum,
	ColorSequence = { new = function(a, b) return { A = a, B = b or a } end },
	NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end },
	NumberSequence = { new = function(k) return { Keys = k } end },
	NumberSequenceKeypoint = { new = function(t, v) return { t, v } end },
	RaycastParams = { new = function() return {} end },
	task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end },
	os = { clock = function() return clock end },
	warn = function(...) print("WARN", ...) end,
}, { __index = getfenv() })

local f = assert(loadstring(WX_SOURCE, "=WeatherFx"))
setfenv(f, env)
local W = f()

-- 1. the pure plan
local p = W.Plan("Rain", "Day", true, false, false)
check(p.Rain == 420 and p.Snow == 0 and p.Tint == "Rain" and p.Lamps == false, "rain plan: 420/s, rain tint, lamps off by day",
	p.Rain .. " " .. p.Snow .. " " .. p.Tint .. " " .. tostring(p.Lamps))
p = W.Plan("Rain", "Night", true, true, false)
check(p.Rain == 50 and p.Lamps == true, "under a roof: 12% of the rain, lamps on at night", p.Rain .. " " .. tostring(p.Lamps))
p = W.Plan("Rain", "Day", true, false, true)
check(p.Rain == 231, "phones: 55% of the rain", p.Rain)
p = W.Plan("Snow", "Dusk", true, false, false)
check(p.Snow == 110 and p.Rain == 0 and p.Tint == "Snow" and p.Lamps == true, "snow plan: 110/s slow flakes, snow tint, lamps at dusk",
	p.Snow .. " " .. p.Tint .. " " .. tostring(p.Lamps))
p = W.Plan("Rain", "Night", false, false, false)
check(p.Rain == 0 and p.Snow == 0 and p.Tint == "Clear" and p.Lamps == true, "off: no rain, no tint, the lamps still follow the night",
	p.Rain .. " " .. p.Tint .. " " .. tostring(p.Lamps))
p = W.Plan("Clear", "Day", true, false, false)
check(p.Rain == 0 and p.Snow == 0 and p.Tint == "Clear", "clear: nothing falls", p.Rain .. " " .. p.Tint)
check(W.LampsOn("Dusk") == true and W.LampsOn("Night") == true and W.LampsOn("Dawn") == false and W.LampsOn("Day") == false,
	"lamps: on at Dusk / Night, off at Dawn / Day", "")
check(W.LampsOn(nil) == nil and W.LampsOn("Noon") == nil, "no phase yet: the lamps are left alone", tostring(W.LampsOn(nil)))

-- 2. start: night rain
W.Init({})
W.Start()
local part = nil
for _, o in made do if o.ClassName == "Part" and o.Name == "WeatherFxEmitter" then part = o end end
check(part ~= nil and part.Parent == camera, "the emitter part lives under the camera (this client only)", part and part.Parent)
check(part and part.Anchored == true and part.CanCollide == false and part.CanQuery == false and part.CanTouch == false
	and part.Transparency == 1 and part.CastShadow == false, "the emitter is anchored, invisible, never collides / queries / touches", "")
local rain = part and part:FindFirstChild("Rain")
local snow = part and part:FindFirstChild("Snow")
check(rain and rain.Rate == 420 and rain.Enabled == true and snow and snow.Enabled == false, "night rain: the rain emitter runs, snow off",
	rain and rain.Rate)
check(rain and rain.Texture == "rbxassetid://77226041980480" and snow and snow.Texture == "rbxassetid://117774040305599",
	"our own textures (Fx_RainStreak, Fx_SnowFlake)", rain and rain.Texture)
check(rain and tostring(rain.Orientation) == "ParticleOrientation.FacingCameraWorldUp",
	"rain streaks stand upright (FacingCameraWorldUp: VelocityParallel laid them sideways)", rain and tostring(rain.Orientation))
check(rain and rain.Color and rain.Color.A and rain.Color.A.R == 196 and rain.LightEmission == 0.2,
	"night rain: the pale glowing streak", rain and rain.Color and rain.Color.A and rain.Color.A.R)
local tint = lighting:FindFirstChild("WeatherTint")
check(tint ~= nil and tint.ClassName == "ColorCorrectionEffect", "a client ColorCorrection WeatherTint for the wet look", tint)
check(lampLight.Enabled == true and lanternLight.Enabled == true, "night: the tagged lamp and the marked lantern light are on",
	tostring(lampLight.Enabled) .. " " .. tostring(lanternLight.Enabled))
check(plainLight.Enabled == true, "an unmarked light is never touched", tostring(plainLight.Enabled))

-- 3. the camera moves: the part follows over it, a little ahead
camera.CFrame = { Position = vec(100, 40, 0), LookVector = vec(1, 0, 0) }
clock += 1
render.fn()
check(part.CFrame and part.CFrame.Position.Y == 40 + 32 and part.CFrame.Position.X == 100 + 14,
	"the emitter follows 32 studs over the camera, 14 ahead", part.CFrame and (part.CFrame.Position.X .. "," .. part.CFrame.Position.Y))

-- 4. a roof over me: the rain thins out
roofHit = { Instance = { Transparency = 0 } }
clock += 1
render.fn()
check(rain.Rate == 50, "under a roof the rain drops to 12%", rain.Rate)
roofHit = nil
clock += 1
render.fn()
check(rain.Rate == 420, "out from under the roof the rain comes back", rain.Rate)

-- 5. day: the marked lamps go off, the unmarked light stays
setState("DayPhase", "Day")
check(rain.Color.A.R == 128 and rain.LightEmission == 0, "day rain: the darker blue-grey streak (seen on a bright sky)",
	rain.Color.A.R)
check(lampLight.Enabled == false and lanternLight.Enabled == false and plainLight.Enabled == true,
	"day: the marked lamps off, the unmarked light untouched", tostring(lampLight.Enabled) .. tostring(plainLight.Enabled))

-- 6. a lamp added later inside the marked lantern follows the current state
setState("DayPhase", "Night")
local late = obj("PointLight", "LateLight")
late.Enabled = false
late.Parent = lanternBulb
descAdded:Fire(late)
check(late.Enabled == true, "a light added later inside a marked lantern follows the night", tostring(late.Enabled))

-- 7. weather effects off (Settings): no rain, the lamps still at night
W.SetEnabled(false)
check(rain.Enabled == false and rain.Rate == 0 and W.IsEnabled() == false, "off: the rain stops", rain.Rate)
check(lampLight.Enabled == true, "off: the lamps still follow the night", tostring(lampLight.Enabled))
setState("DayPhase", "Day")
local offDay = lampLight.Enabled
setState("DayPhase", "Night")
check(offDay == false and lampLight.Enabled == true, "off: the lamps still go off by day and on at night",
	tostring(offDay) .. " " .. tostring(lampLight.Enabled))
W.SetEnabled(true)
setState("Weather", "Snow")
check(snow.Enabled == true and snow.Rate == 110 and rain.Enabled == false, "snow: the flakes run, the rain stops", snow.Rate)

-- 8. no phase from the server yet: lamps left as they are
setState("DayPhase", nil)
lampLight.Enabled = false -- as the place has it
setState("Weather", "Clear")
check(lampLight.Enabled == false, "no phase: a lamp stays as the place has it", tostring(lampLight.Enabled))

-- 9. static rules
check(not string.find(WX_SOURCE, "\"Atmosphere\"", 1, true), "never makes an Atmosphere (A9-3 / A23-30)", "")
check(not string.find(WX_SOURCE, "Lighting%.[A-Z]%w*%s*="), "never writes a Lighting property (ZoneLook owns them)", "")
check(not string.find(WX_SOURCE, "\"Beam\"", 1, true), "no beams / rays", "")

print(string.format("WEATHER_FX_SUMMARY checks=%d failed=%d", checks, failed))
