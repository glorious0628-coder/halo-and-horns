-- A23-91 (user 2026-10-09 "콘솔 게임처럼"): the production CameraFollow console-style follow with vector / camera doubles.
-- Walks are world-fixed (the walk heading stays) or a held stick (camera-relative, like Roblox's ControlModule). Checks
-- the rules: 1 only while walking (a stop brakes quickly, standing never turns), 2 a 15 deg dead zone and a spring with
-- an acceleration cap (no jerk, no overshoot), 3 never toward the camera, sideways slower, 4 a hand turn holds 1.5 s and
-- it builds up again from 0, 5 my swing = 30% for 1.5 s, 6 the pitch untouched, 7 30 / 60 / 144 fps the same and a hitch
-- counts as 1/20 s, 8 <= 90 deg/s (50 with 'Screen shake' off / Reduced Motion) and no circle under 45 studs; off for
-- Free, windows, shift lock, first person and Roblox's own Follow camera.
-- Input: SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function show(t)
	if type(t) ~= "table" then return tostring(t) end
	local parts = {}
	for k, v in t do table.insert(parts, tostring(k) .. "=" .. tostring(v)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
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
local W = { Clock = 100, Settings = { Cam = "Follow", Shake = true }, AutoRotate = true }
local focus = vec(0, 5, 0)
local camera = { CameraType = "Custom", Focus = { Position = focus }, ViewportSize = vec(1000, 600, 0) }
camera.CFrame = lookAt(vec(0, 9, 12), focus) -- behind me (+Z), looking along -Z and a little down
camera.Signals = { CameraType = signal(), CameraSubject = signal() }
function camera:GetPropertyChangedSignal(n) return self.Signals[n] end
local workspace = { CurrentCamera = camera, Signal = signal() }
function workspace:GetPropertyChangedSignal() return self.Signal end
local root = { CFrame = { LookVector = vec(0, 0, -1) } }
local humanoid = { MoveDirection = vec(0, 0, 0), Health = 100, RootPart = root, WalkSpeed = 20,
	IsA = function(_, n) return n == "Humanoid" end }
local character = { AncestryChanged = signal(), ChildAdded = signal(), ChildRemoved = signal() }
function character:IsDescendantOf() return true end
function character:FindFirstChildOfClass() return humanoid end
-- Roblox's camera movement modes (Dev* on the player, the player's own choice in UserGameSettings)
local DTM = { UserChoice = { Name = "UserChoice" }, Classic = { Name = "Classic" }, Follow = { Name = "Follow" },
	Orbital = { Name = "Orbital" } }
local DCM = { UserChoice = { Name = "UserChoice" }, Classic = { Name = "Classic" }, Follow = { Name = "Follow" } }
local userGame = { TouchCameraMovementMode = { Name = "Default" }, ComputerCameraMovementMode = { Name = "Default" } }
local player = { UserId = 7, Character = character, CharacterAdded = signal(), CharacterRemoving = signal(),
	DevTouchCameraMode = DTM.UserChoice, DevComputerCameraMode = DCM.UserChoice } -- the place: both UserChoice
function player:GetAttribute(n) return n == "DataLoaded" end
local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), PointerAction = signal(),
	MouseBehavior = "Default", RightDown = false, Keys = {}, TextBox = nil, TouchEnabled = false }
function input:GetFocusedTextBox() return self.TextBox end
function input:IsMouseButtonPressed(kind) return kind == "RMB" and self.RightDown end
function input:IsKeyDown(key) return self.Keys[key] == true end
local steps = {}
local run = {}
function run:BindToRenderStep(name, priority, fn) steps[name] = { Priority = priority, Fn = fn } end
local fxSignal = signal()
local net = { Get = function(name) assert(name == "Fx", name) return { OnClientEvent = fxSignal } end }
local shared = { WaitForChild = function(_, n) return { __module = n } end }
local gui = { MenuIsOpen = false, ReducedMotionEnabled = false }
local services = { Players = { LocalPlayer = player }, UserInputService = input, GuiService = gui, RunService = run,
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
		Touch = "Touch", Gamepad1 = "Pad", Keyboard = "Keyboard" }, MouseBehavior = { Default = "Default", LockCenter = "LockCenter" },
		KeyCode = { Thumbstick2 = "Thumb2", Left = "Left", Right = "Right", Comma = "Comma", Period = "Period" },
		RenderPriority = { Camera = { Value = 200 } }, DevTouchCameraMovementMode = DTM },
	UserSettings = function()
		return { GetService = function(_, n) assert(n == "UserGameSettings", n) return userGame end }
	end,
	warn = function(...) print("WARN", ...) end,
}, { __index = getfenv() }))
local CF = fn()
CF.Init(registry)
CF.Start()
local FOLLOW = CF.Follow
local step = steps.HHC_CameraFollow
check(step ~= nil and step.Priority == 201, "the follow turn runs every frame right after Roblox's camera (priority 201)",
	step and step.Priority)
-- (3) the place leaves DevTouchCameraMovementMode on UserChoice (phones: Roblox's Follow camera); Start makes it Classic
check(player.DevTouchCameraMode == DTM.Classic and player.DevComputerCameraMode == DCM.UserChoice,
	"(3) Start switches my touch camera to Classic (Roblox's Follow camera would turn on the walk too); the PC choice stays",
	show({ touch = player.DevTouchCameraMode.Name, pc = player.DevComputerCameraMode.Name }))


------------------------------------------------------------------ A23-91 console-style follow (scenarios)
-- the camera's flat heading (rad) and its pitch (LookVector.Y)
local function heading() local l = camera.CFrame.LookVector; return math.atan2(-l.X, -l.Z) end
local function pitch() return camera.CFrame.LookVector.Y end
local function wrap(a) while a > math.pi do a -= 2 * math.pi end while a < -math.pi do a += 2 * math.pi end return a end
local function deg(a) return math.deg(a) end
-- put the camera back behind me looking -Z (heading 0), clear the follow state
local function reset()
	camera.CFrame = lookAt(vec(0, 9, 12), focus)
	FOLLOW.Vel, FOLLOW.LastManual, FOLLOW.LastAttack = 0, -math.huge, -math.huge
	W.Settings.Cam, W.Settings.Shake = "Follow", true
	input.RightDown, input.MouseBehavior = false, "Default"
	humanoid.MoveDirection = vec(0, 0, 0)
	W.Clock += 10
end
-- a world-fixed walk at `walkHeading` (rad, 0 = -Z, + = left) for `seconds` at `fps`; returns the per-frame yaws (rad)
local function walkWorld(walkHeading, seconds, fps, length)
	local yaws = {}
	local n = math.floor(seconds * fps + 0.5)
	local l = length or 1
	for _ = 1, n do
		humanoid.MoveDirection = vec(-math.sin(walkHeading) * l, 0, -math.cos(walkHeading) * l)
		local before = heading()
		step.Fn(1 / fps)
		W.Clock += 1 / fps
		table.insert(yaws, wrap(heading() - before))
	end
	return yaws
end
-- a held stick / keys `stickDeg` off forward (camera-relative, like Roblox's ControlModule): + = left
local function walkStick(stickDeg, seconds, fps)
	local yaws = {}
	local n = math.floor(seconds * fps + 0.5)
	for _ = 1, n do
		local h = heading() + math.rad(stickDeg)
		humanoid.MoveDirection = vec(-math.sin(h), 0, -math.cos(h))
		local before = heading()
		step.Fn(1 / fps)
		W.Clock += 1 / fps
		table.insert(yaws, wrap(heading() - before))
	end
	return yaws
end
local function stand(seconds, fps)
	humanoid.MoveDirection = vec(0, 0, 0)
	local yaws = {}
	for _ = 1, math.floor(seconds * fps + 0.5) do
		local before = heading()
		step.Fn(1 / fps)
		W.Clock += 1 / fps
		table.insert(yaws, wrap(heading() - before))
	end
	return yaws
end
local function sum(t) local s = 0 for _, v in t do s += v end return s end
local function maxAbs(t) local m = 0 for _, v in t do m = math.max(m, math.abs(v)) end return m end

-- 1. standing still never turns (the old recenter is gone)
reset()
root.CFrame = { LookVector = vec(-1, 0, 0) } -- my body faces sideways
local st = stand(3, 60)
check(maxAbs(st) == 0, "1 standing still (body sideways) never turns the camera (no recenter)", deg(maxAbs(st)))

-- 2. walking straight ahead / within the 15 deg dead zone: no turn
reset()
local fwd = walkWorld(0, 2, 60)
check(maxAbs(fwd) == 0, "2 walking straight ahead: no turn", deg(maxAbs(fwd)))
reset()
local small = walkWorld(math.rad(12), 2, 60)
check(maxAbs(small) == 0, "2 a walk 12 deg off the look (inside 15 deg): no turn", deg(maxAbs(small)))

-- 3. a world-fixed walk 60 deg left: turns left, smoothly, and settles at the dead zone edge with no overshoot
reset()
local left = walkWorld(math.rad(60), 4, 60)
local turned = sum(left)
check(turned > 0, "3 a walk 60 deg left turns the camera left", deg(turned))
check(math.abs(deg(turned) - 45) < 1.5, "3 it settles 15 deg short of the walk (the dead zone edge), no overshoot", deg(turned))
check(math.abs(left[1]) < math.rad(0.2), "3 it starts gently (the first frame turns < 0.2 deg)", deg(left[1]))
local jerk = 0
for i = 2, #left do jerk = math.max(jerk, math.abs(left[i] - left[i - 1]) * 60 * 60) end -- rad / s^2
check(jerk <= math.rad(240) + 1e-6, "3 the turn speed changes by at most 240 deg/s per s (no jerk)", deg(jerk))
local overshoot = 0
for _, y in left do if y < 0 then overshoot += 1 end end
check(overshoot == 0, "3 it never swings back the other way", overshoot)

-- 8. never above the 90 deg/s cap; 'Screen shake' off = 50 deg/s
reset()
humanoid.WalkSpeed = 100 -- fast enough that the radius cap is not the limit
local big = walkWorld(math.rad(100), 3, 60)
check(maxAbs(big) * 60 <= math.rad(90) + 1e-6, "8 never above 90 deg/s (motion sickness cap)", deg(maxAbs(big) * 60))
local bigJerk = 0
for i = 2, #big do bigJerk = math.max(bigJerk, math.abs(big[i] - big[i - 1]) * 60 * 60) end
check(bigJerk <= math.rad(240) + 1e-6, "2 a fast walk: still at most 240 deg/s per s (no jerk)", deg(bigJerk))
check(sum(big) <= math.rad(85) + math.rad(0.5), "2 a fast walk never turns past the dead zone edge (85 deg)", deg(sum(big)))
reset()
humanoid.WalkSpeed = 100
local fast60 = walkWorld(math.rad(60), 3, 60)
local fastJerk = 0
for i = 2, #fast60 do fastJerk = math.max(fastJerk, math.abs(fast60[i] - fast60[i - 1]) * 60 * 60) end
check(fastJerk <= math.rad(240) + 1e-6, "2 a fast diagonal walk: at most 240 deg/s per s (the acceleration cap)", deg(fastJerk))
check(sum(fast60) <= math.rad(45) + 1e-6, "2 a fast diagonal walk stops exactly at the dead zone edge (45 deg)", deg(sum(fast60)))
humanoid.WalkSpeed = 100
reset()
W.Settings.Shake = false
local bigSlow = walkWorld(math.rad(100), 3, 60)
check(maxAbs(bigSlow) * 60 <= math.rad(50) + 1e-6 and maxAbs(bigSlow) > 0, "8 'Screen shake' off: at most 50 deg/s", deg(maxAbs(bigSlow) * 60))
reset()
gui.ReducedMotionEnabled = true
local bigReduced = walkWorld(math.rad(100), 3, 60)
gui.ReducedMotionEnabled = false
check(maxAbs(bigReduced) * 60 <= math.rad(50) + 1e-6, "8 Roblox's Reduced Motion: at most 50 deg/s", deg(maxAbs(bigReduced) * 60))
humanoid.WalkSpeed = 20

-- 8. a held stick never circles tighter than 45 studs (the cap <= speed / MinRadius)
reset()
local stick = walkStick(40, 4, 60)
local rate = maxAbs(stick) * 60
check(rate > 0 and rate <= 20 / 45 + 1e-6, "8 a held 40 deg stick: <= speed / 45 studs (no tight circle)", deg(rate))
reset()
local stickBack = walkStick(-40, 2, 60)
check(sum(stickBack) < 0, "a held stick to the right turns the camera right", deg(sum(stickBack)))

-- 3. walking toward the camera never turns; sideways is slower than forward-ish
reset()
local back = walkWorld(math.rad(160), 2, 60)
check(maxAbs(back) == 0, "3 walking toward the camera (160 deg) never turns it", deg(maxAbs(back)))
reset()
humanoid.WalkSpeed = 100
local side = walkWorld(math.rad(90), 0.5, 60)
reset()
humanoid.WalkSpeed = 100
local diag = walkWorld(math.rad(60), 0.5, 60)
humanoid.WalkSpeed = 20
check(sum(side) > 0 and sum(side) < sum(diag), "3 a sideways walk turns slower than a diagonal one", deg(sum(side)) .. " vs " .. deg(sum(diag)))

-- 1. a stop brakes it quickly: < 3 deg more after the stop, still within 0.4 s
reset()
humanoid.WalkSpeed = 100
walkWorld(math.rad(100), 0.6, 60)
local after = stand(1, 60)
humanoid.WalkSpeed = 20
local tail = 0
for i = 25, #after do tail = math.max(tail, math.abs(after[i])) end
check(math.abs(sum(after)) < math.rad(3), "1 after a stop it turns < 3 deg more", deg(sum(after)))
check(tail == 0, "1 and is still within 0.4 s", deg(tail))

-- 4. a hand turn stops it for 1.5 s, then it builds up again from 0
reset()
input.RightDown = true
step.Fn(1 / 60)
input.RightDown = false
local held = walkWorld(math.rad(60), 1.4, 60)
check(maxAbs(held) == 0, "4 a right drag: no follow for 1.5 s", deg(maxAbs(held)))
local resume = walkWorld(math.rad(60), 0.6, 60)
check(sum(resume) > 0, "4 after the hold it follows again", deg(sum(resume)))
local firstOn = 0
for _, y in resume do if y ~= 0 then firstOn = y break end end
check(math.abs(firstOn) < math.rad(0.2), "4 ... starting gently from 0 (no snap)", deg(firstOn))
-- 4. a hand turn while it is turning: on the way back it starts gently from 0 (no snap)
reset()
humanoid.WalkSpeed = 100
walkWorld(math.rad(100), 0.5, 60)
input.RightDown = true
step.Fn(1 / 60)
input.RightDown = false
walkWorld(math.rad(100), 1.5, 60)
local again = walkWorld(math.rad(100), 0.2, 60)
humanoid.WalkSpeed = 20
local againFirst = 0
for _, y in again do if y ~= 0 then againFirst = y break end end
check(againFirst ~= 0 and math.abs(againFirst) < math.rad(0.2), "4 after a hand turn mid-turn it starts again from 0", deg(againFirst))
reset()
input.Keys.Left = true
step.Fn(1 / 60)
input.Keys.Left = nil
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "4 Roblox's keyboard turn (Left arrow) is a hand turn too")
reset()
input.InputChanged:Fire({ UserInputType = "Pad", KeyCode = "Thumb2", Position = vec(0.9, 0, 0) }, false)
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "4 the right stick is a hand turn")

-- 5. after my swing it turns at 30% for 1.5 s (other players' swings change nothing)
reset()
humanoid.WalkSpeed = 100
local free = sum(walkWorld(math.rad(100), 0.5, 60))
reset()
humanoid.WalkSpeed = 100
fxSignal:Fire("Swing", { UserId = 7 })
local fight = sum(walkWorld(math.rad(100), 0.5, 60))
reset()
humanoid.WalkSpeed = 100
fxSignal:Fire("Swing", { UserId = 99 })
local other = sum(walkWorld(math.rad(100), 0.5, 60))
humanoid.WalkSpeed = 20
check(fight > 0 and fight < free * 0.45, "5 after my swing: much weaker (30%)", deg(fight) .. " vs " .. deg(free))
check(math.abs(other - free) < 1e-6, "5 another player's swing changes nothing", deg(other))

-- 6. the pitch is never touched
reset()
local p0 = pitch()
walkWorld(math.rad(80), 2, 60)
check(math.abs(pitch() - p0) < 1e-9, "6 the camera's up / down angle stays where the player put it", pitch() - p0)

-- 7. frame-rate free: the same walk at 30, 60 and 144 fps ends within 1 deg
local ends = {}
for _, fps in { 30, 60, 144 } do
	reset()
	table.insert(ends, sum(walkWorld(math.rad(70), 1.5, fps)))
end
check(math.abs(ends[1] - ends[2]) < math.rad(1) and math.abs(ends[3] - ends[2]) < math.rad(1),
	"7 30 / 60 / 144 fps turn the same (within 1 deg)", deg(ends[1]) .. " / " .. deg(ends[2]) .. " / " .. deg(ends[3]))
reset()
humanoid.MoveDirection = vec(-math.sin(math.rad(100)), 0, -math.cos(math.rad(100)))
humanoid.WalkSpeed = 100
local h0 = heading()
step.Fn(0.5) -- a hitch
humanoid.WalkSpeed = 20
check(math.abs(wrap(heading() - h0)) <= math.rad(90) / 20 + 1e-6, "7 a 0.5 s hitch counts as 1/20 s", deg(wrap(heading() - h0)))

-- off: Free, windows, shift lock, first person, Roblox's own Follow camera
reset()
W.Settings.Cam = "Free"
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "Settings Camera = Free: no follow")
reset()
W.Settings.Cam = nil
check(sum(walkWorld(math.rad(60), 1, 60)) > 0, "no camera setting yet: it follows (the default is Follow, A23-91)")
reset()
registry.Panels.Open = true
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "a window open: no follow")
registry.Panels.Open = false
reset()
input.MouseBehavior = "LockCenter"
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "shift lock: no follow")
reset()
camera.CFrame = lookAt(vec(0, 5.2, 0.5), focus)
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "first person: no follow")
reset()
player.DevComputerCameraMode = DCM.Follow
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "Roblox's own Follow camera active: ours stays off (never two turns)")
player.DevComputerCameraMode = DCM.UserChoice
reset()
input.TouchEnabled = true
local stickTouch = { UserInputType = "Touch", Position = vec(100, 400, 0) } -- the move stick (left side)
input.InputBegan:Fire(stickTouch, false)
input.InputChanged:Fire(stickTouch, false)
check(sum(walkWorld(math.rad(60), 1, 60)) > 0, "phone: the move stick's touch never counts as a hand turn")
input.InputEnded:Fire(stickTouch)
reset()
local camTouch = { UserInputType = "Touch", Position = vec(800, 300, 0) } -- a drag on the camera side
input.InputBegan:Fire(camTouch, false)
input.InputChanged:Fire(camTouch, false)
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "phone: a finger drag on the camera side is a hand turn")
input.InputEnded:Fire(camTouch)
reset()
player.DevTouchCameraMode = DTM.UserChoice -- Roblox's touch default is its Follow camera
check(maxAbs(walkWorld(math.rad(60), 1, 60)) == 0, "phone on Roblox's default (Follow) touch camera: ours stays off")
player.DevTouchCameraMode = DTM.Classic
input.TouchEnabled = false
print("CAMERA_FOLLOW_SUMMARY checks=" .. checks .. " failed=" .. failed)
