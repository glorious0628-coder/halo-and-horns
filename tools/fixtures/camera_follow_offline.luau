-- A23-65 (user 2026-10-07): the production CameraFollow follow turn with vector / camera doubles. While walking the
-- camera turns slowly around its Focus toward the walking direction (capped per second, eased, slower with 'Screen
-- shake' off); never while standing, walking toward the camera, 1.5 s after a hand turn, 0.5 s after my swing / skill,
-- in shift lock / first person, when blocked, or with Settings Cam = "Free". Input: SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function signal()
	local rows, s = {}, {}
	function s:Connect(fn) table.insert(rows, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in table.clone(rows) do fn(...) end end
	return s
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return vec(v.X / m, v.Y / m, v.Z / m) end
	return nil
end
local function lookAt(pos, target) return { Position = pos, LookVector = (target - pos).Unit } end
local W = { Clock = 100, Settings = { Cam = "Follow", Shake = true } }
local focus = vec(0, 5, 0)
local camera = { CameraType = "Custom", Focus = { Position = focus }, ViewportSize = vec(1000, 600, 0) }
camera.CFrame = lookAt(vec(0, 9, 12), focus) -- behind me (+Z), looking along -Z and a little down
camera.Signals = { CameraType = signal(), CameraSubject = signal() }
function camera:GetPropertyChangedSignal(n) return self.Signals[n] end
local workspace = { CurrentCamera = camera, Signal = signal() }
function workspace:GetPropertyChangedSignal() return self.Signal end
local humanoid = { MoveDirection = vec(0, 0, 0), IsA = function(_, n) return n == "Humanoid" end }
local character = { AncestryChanged = signal(), ChildAdded = signal(), ChildRemoved = signal() }
function character:IsDescendantOf() return true end
function character:FindFirstChildOfClass() return humanoid end
local player = { UserId = 7, Character = character, CharacterAdded = signal(), CharacterRemoving = signal() }
function player:GetAttribute(n) return n == "DataLoaded" end
local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), MouseBehavior = "Default", RightDown = false }
function input:GetFocusedTextBox() return nil end
function input:IsMouseButtonPressed(kind) return kind == "RMB" and self.RightDown end
local steps = {}
local run = {}
function run:BindToRenderStep(name, priority, fn) steps[name] = { Priority = priority, Fn = fn } end
local fxSignal = signal()
local net = { Get = function(name) assert(name == "Fx", name) return { OnClientEvent = fxSignal } end }
local shared = { WaitForChild = function(_, n) return { __module = n } end }
local services = { Players = { LocalPlayer = player }, UserInputService = input, GuiService = { MenuIsOpen = false }, RunService = run,
	ReplicatedStorage = { WaitForChild = function() return shared end } }
local registry = { Settings = { Get = function(k) return W.Settings[k] end } }
for _, name in { "FactionPicker", "ClassPicker", "Panels", "WorldMap" } do
	local m = { Open = false }; m.IsOpen = function() return m.Open end; registry[name] = m
end
local fn = assert(loadstring(SOURCE))
setfenv(fn, setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end }, workspace = workspace,
	Instance = { new = function() local s = signal(); return { Event = s, Fire = function() s:Fire() end } end },
	Vector3 = { new = vec, zero = vec(0, 0, 0) }, CFrame = { lookAt = lookAt },
	task = { defer = function(cb) cb() end, spawn = function(cb) cb() end },
	require = function(m) assert(m.__module == "Net", tostring(m.__module)) return net end,
	os = { clock = function() return W.Clock end },
	Enum = { CameraType = { Custom = "Custom" }, UserInputType = { MouseButton1 = "LMB", MouseButton2 = "RMB", MouseMovement = "Move",
		Touch = "Touch", Gamepad1 = "Pad" }, MouseBehavior = { Default = "Default", LockCenter = "LockCenter" },
		KeyCode = { Thumbstick2 = "Thumb2" }, RenderPriority = { Camera = { Value = 200 } } },
	warn = function(...) print("WARN", ...) end,
}, { __index = getfenv() }))
local CF = fn()
CF.Init(registry)
CF.Start()
local step = steps.HHC_CameraFollow
check(step ~= nil and step.Priority == 201, "the follow turn runs every frame right after Roblox's camera (priority 201)",
	step and step.Priority)

local function yaw(look) return math.deg(math.atan2(-look.X, -look.Z)) end -- 0 = looking along -Z, + = turned left
local function frame(n, dt)
	for _ = 1, n or 1 do
		W.Clock += dt or 1 / 60
		step.Fn(dt or 1 / 60)
	end
end
local function reset()
	camera.CFrame = lookAt(vec(0, 9, 12), focus)
	camera.CameraType = "Custom"
	humanoid.MoveDirection = vec(0, 0, 0)
	input.RightDown, input.MouseBehavior = false, "Default"
	W.Settings.Cam, W.Settings.Shake = "Follow", true
	camera.Focus.Position = focus
	W.Clock += 10 -- past every hold
end
local function dist() return (camera.CFrame.Position - camera.Focus.Position).Magnitude end

-- 1. walking to my right (+X): the camera turns toward it, capped at 110 deg/s, orbiting the focus
reset()
local d0, y0 = dist(), yaw(camera.CFrame.LookVector)
humanoid.MoveDirection = vec(1, 0, 0)
frame(1)
local y1 = yaw(camera.CFrame.LookVector)
check(y1 < y0 and math.abs(y1 - y0) <= 45 / 60 + 1e-6 and math.abs(y1 - y0) > 0.5, "walking right turns the camera right, at most 45 deg/s",
	{ y0, y1 })
check(math.abs(dist() - d0) < 1e-6 and math.abs(camera.CFrame.LookVector.Y - lookAt(vec(0, 9, 12), focus).LookVector.Y) < 1e-6,
	"it orbits the focus: same distance, same downward tilt", { dist(), d0 })
frame(480)
local y2 = yaw(camera.CFrame.LookVector)
check(math.abs(y2 - (-90)) <= 6 + 1e-6 and y2 >= -90 - 1e-6, "after a while it settles behind me (within the 6 deg dead zone, no overshoot)", y2)
-- 2. standing / walking toward the camera: never turns
reset()
frame(60)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "standing still: the camera stays", yaw(camera.CFrame.LookVector))
humanoid.MoveDirection = vec(0, 0, 1)
frame(60)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "walking toward the camera (backing up): never spins", yaw(camera.CFrame.LookVector))
humanoid.MoveDirection = vec(0.97, 0, 0.2) -- mostly sideways, a bit toward the camera (102 deg from the camera look): still follows
frame(1)
check(yaw(camera.CFrame.LookVector) < -0.2, "walking sideways (a little toward the camera) still follows", yaw(camera.CFrame.LookVector))
-- 3. a hand turn holds it for 1.5 s
reset()
humanoid.MoveDirection = vec(1, 0, 0)
input.RightDown = true
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "while the right button is down: no follow (Roblox's right drag owns the camera)")
input.RightDown = false
frame(60) -- 1.0 s after the drag
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "1.0 s after the right drag: still no follow")
frame(36) -- 1.6 s
check(yaw(camera.CFrame.LookVector) < -0.2, "1.5 s after the right drag: the follow comes back", yaw(camera.CFrame.LookVector))
reset()
humanoid.MoveDirection = vec(1, 0, 0)
local right = { UserInputType = "Touch", Position = vec(800, 300, 0) }
input.InputBegan:Fire(right, false)
input.InputChanged:Fire(right, false)
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "a finger drag on the camera side holds the follow")
reset()
humanoid.MoveDirection = vec(1, 0, 0)
local left = { UserInputType = "Touch", Position = vec(150, 450, 0) }
input.InputBegan:Fire(left, false)
input.InputChanged:Fire(left, false)
frame(1)
check(yaw(camera.CFrame.LookVector) < -0.2, "a finger on the move stick (left side) does not hold the follow", yaw(camera.CFrame.LookVector))
input.InputEnded:Fire(left, false)
reset()
humanoid.MoveDirection = vec(1, 0, 0)
input.InputChanged:Fire({ UserInputType = "Pad", KeyCode = "Thumb2", Position = vec(0.8, 0, 0) }, false)
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "the right stick holds the follow")
-- 4. my own swing / skill holds it 0.5 s; another player's never
reset()
humanoid.MoveDirection = vec(1, 0, 0)
fxSignal:Fire("Swing", { UserId = 7 })
frame(24) -- 0.4 s
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "0.4 s after my swing: no follow (FaceTarget never whips the camera)")
frame(9) -- 0.55 s
check(yaw(camera.CFrame.LookVector) < -0.2, "0.5 s after my swing: follows again", yaw(camera.CFrame.LookVector))
for _, kind in { "Release", "Skill" } do
	reset()
	humanoid.MoveDirection = vec(1, 0, 0)
	fxSignal:Fire(kind, { UserId = 7 })
	frame(12)
	check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "my " .. kind .. " holds the follow too")
end
reset()
humanoid.MoveDirection = vec(1, 0, 0)
fxSignal:Fire("Swing", { UserId = 99 })
frame(1)
check(yaw(camera.CFrame.LookVector) < -0.2, "another player's swing does not hold my camera")
-- 5. switches and states
reset()
humanoid.MoveDirection = vec(1, 0, 0)
W.Settings.Cam = "Free"
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "Settings Camera = Free: no follow")
reset()
humanoid.MoveDirection = vec(1, 0, 0)
W.Settings.Shake = false
frame(1)
local slowStep = math.abs(yaw(camera.CFrame.LookVector))
check(slowStep > 0.2 and slowStep <= 25 / 60 + 1e-6, "'Screen shake' off: the follow turns slower (25 deg/s)", slowStep)
reset()
humanoid.MoveDirection = vec(1, 0, 0)
registry.Panels.Open = true
frame(30)
registry.Panels.Open = false
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "a window open: no follow")
reset()
humanoid.MoveDirection = vec(1, 0, 0)
camera.CameraType = "Scriptable"
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "a scripted camera (the opening): no follow")
reset()
humanoid.MoveDirection = vec(1, 0, 0)
input.MouseBehavior = "LockCenter"
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "shift lock: no follow (it turns me itself)")
reset()
humanoid.MoveDirection = vec(1, 0, 0)
camera.Focus.Position = camera.CFrame.Position + vec(0, 0, -0.5)
frame(30)
check(math.abs(yaw(camera.CFrame.LookVector)) < 1e-9, "first person: no follow")
print("CAMERA_FOLLOW_SUMMARY checks=" .. checks .. " failed=" .. failed)
