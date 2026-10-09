-- A23-65 + A23-74 (user 2026-10-07 "카메라가 자동으로 뒤에 있어야 하는데 왜 안 돌아 / 카메라도 뒤통수 따라가랬잖아"): the
-- production CameraFollow follow turn and recenter with vector / camera doubles. Humanoid AutoRotate is simulated (the
-- root faces MoveDirection while walking) and held keys / the stick are camera-relative like Roblox's ControlModule.
-- 1. Walking: the camera turns toward the walk, capped by the angle off the camera look (45 deg/s within 20 deg, a smooth
--    fade to 16 deg/s by 60 deg), so W+D / D / a 37-60 deg stick make wide arcs (radius >= 55 studs at WalkSpeed 20);
--    never while backing up toward the camera.
-- 2. Standing: 0.25 s after the walk ends the camera eases round behind the root's facing (ease in, <= 120 deg/s, ease
--    out): a 90 deg side view is within 8 deg in 1.2 s; a dead zone keeps it still once behind; never after a backpedal.
-- 3. Neither during a hand turn hold (1.5 s; a hand turn while standing keeps my view until the next walk), my swing /
--    skill hold (0.5 s, then the recenter resumes), Cam = "Free", windows / scripted camera, shift lock, first person.
-- 'Screen shake' off / Reduced Motion = slower. Phone: the left thumbstick drives it, its touch never holds it.
-- Review A23-74 (user 2026-10-07): (1) Roblox's keyboard / trackpad camera turn (Left / Right arrows, Comma / Period,
-- a trackpad pan) is a hand turn, never pulled back; (2) a stick held anywhere from 0 to 110 deg off forward walks a
-- circle of radius >= 50 studs (the cap <= speed / 55 studs; a half-pushed stick and a slower walk too); (3) Start
-- switches my touch camera to Classic, and while Roblox's Follow camera is active (touch or a PC player's choice) the
-- walking turn stays off; (4) a 0.5 s hitch turns as if it were 1/20 s.
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

local DT = 1 / 60
local WALK = 20 -- Config.Player.WalkSpeed (studs / s)
local function yaw(look) return math.deg(math.atan2(-look.X, -look.Z)) end -- 0 = looking along -Z, + = turned left
local function camYaw() return yaw(camera.CFrame.LookVector) end
local function rootYaw() return yaw(root.CFrame.LookVector) end
local function diff(a, b) return (a - b + 540) % 360 - 180 end -- a - b in (-180, 180]
local function face(v)
	local m = math.sqrt(v.X * v.X + v.Z * v.Z)
	root.CFrame = { LookVector = vec(v.X / m, 0, v.Z / m) }
end
local function faceYaw(deg) face(vec(-math.sin(math.rad(deg)), 0, -math.cos(math.rad(deg)))) end -- same convention as yaw()
-- one render frame: Humanoid AutoRotate turns the body to MoveDirection first (physics), then the camera step
local function frame(n)
	for _ = 1, n or 1 do
		W.Clock += DT
		local m = humanoid.MoveDirection
		if W.AutoRotate and m.Magnitude >= 0.2 then face(m) end
		step.Fn(DT)
	end
end
local START_TILT = lookAt(vec(0, 9, 12), focus).LookVector.Y
local function reset()
	camera.CFrame = lookAt(vec(0, 9, 12), focus)
	camera.CameraType = "Custom"
	humanoid.MoveDirection = vec(0, 0, 0)
	humanoid.Health = 100
	root.CFrame = { LookVector = vec(0, 0, -1) } -- facing the camera look: already behind me
	input.RightDown, input.MouseBehavior = false, "Default"
	W.Settings.Cam, W.Settings.Shake = "Follow", true
	gui.ReducedMotionEnabled = false
	humanoid.WalkSpeed = WALK
	input.Keys, input.TextBox, input.TouchEnabled = {}, nil, false
	player.DevTouchCameraMode, player.DevComputerCameraMode = DTM.Classic, DCM.UserChoice -- as Start left them
	userGame.TouchCameraMovementMode, userGame.ComputerCameraMovementMode = { Name = "Default" }, { Name = "Default" }
	for _, name in { "FactionPicker", "ClassPicker", "Panels", "WorldMap" } do registry[name].Open = false end
	camera.Focus.Position = focus
	W.Clock += 10 -- past every hold
	frame(30) -- standing: settles the stop bookkeeping
end
local function dist() return (camera.CFrame.Position - camera.Focus.Position).Magnitude end
local function still() return math.abs(diff(camYaw(), 0)) < 1e-9 end
-- MoveDirection of a key / stick input relative to the camera (Roblox's ControlModule: W = camera look, D = its right)
local function camRelative(right, fwd)
	local l = camera.CFrame.LookVector
	local m = math.sqrt(l.X * l.X + l.Z * l.Z)
	local fx, fz = l.X / m, l.Z / m
	local x, z = fwd * fx - right * fz, fwd * fz + right * fx
	local k = math.sqrt(x * x + z * z)
	return vec(x / k, 0, z / k)
end
-- hold a camera-relative input for `seconds` (each frame recomputed, like a held key / stick): studs walked, deg turned
-- (+ = right), and the largest one-frame turn (deg). Only CameraFollow's own turn counts (`each` runs first, so a
-- simulated Roblox camera turn in it is left out). push = how far the stick is pushed (Roblox walks WalkSpeed * push)
local function hold(right, fwd, seconds, each, push)
	local walked, turned, maxStep = 0, 0, 0
	push = push or 1
	for i = 1, math.floor(seconds * 60 + 0.5) do
		if each then each(i) end
		humanoid.MoveDirection = camRelative(right, fwd) * push
		local before = camYaw()
		frame(1)
		local d = diff(before, camYaw())
		turned += d
		maxStep = math.max(maxStep, math.abs(d))
		walked += humanoid.WalkSpeed * push * DT
	end
	return walked, turned, maxStep
end
-- Roblox's own camera turn (its keyboard / trackpad turn, before CameraFollow's step): yaw round the focus, + = left
local function robloxTurn(deg)
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	local f = camera.Focus.Position
	local function rot(v) return vec(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c) end
	local pos = f + rot(camera.CFrame.Position - f)
	camera.CFrame = lookAt(pos, pos + rot(camera.CFrame.LookVector))
end
local KEY_TURN = 120 -- deg / s: Roblox's keyboard camera turn (CameraInput ROTATION_SPEED_KEYS)
local function radius(walked, turned) return walked / math.max(1e-9, math.rad(math.abs(turned))) end
-- stop walking and watch for `seconds`: when the camera first moved (s after the stop), the first moving step, the
-- largest step (deg / frame), the camera-to-facing angle at `at` s and at the end, overshoot, distance / tilt drift
local function stopAndWatch(seconds, at, each)
	humanoid.MoveDirection = vec(0, 0, 0)
	local r = { FirstMove = math.huge, FirstStep = 0, MaxStep = 0, Overshoot = false, Start = diff(camYaw(), rootYaw()) }
	local d0, sign = dist(), (r.Start >= 0 and 1 or -1)
	r.DistDrift, r.TiltDrift = 0, 0
	for i = 1, math.floor(seconds * 60 + 0.5) do
		if each then each(i * DT) end
		local before = camYaw()
		frame(1)
		local d = math.abs(diff(camYaw(), before))
		if d > 1e-9 and r.FirstMove == math.huge then r.FirstMove, r.FirstStep = i * DT, d end
		r.MaxStep = math.max(r.MaxStep, d)
		local off = diff(camYaw(), rootYaw())
		if off * sign < -1.0 then r.Overshoot = true end
		if at and math.abs(i * DT - at) < DT / 2 then r.OffAt = math.abs(off) end
		r.DistDrift = math.max(r.DistDrift, math.abs(dist() - d0))
		r.TiltDrift = math.max(r.TiltDrift, math.abs(camera.CFrame.LookVector.Y - START_TILT))
	end
	r.Off = math.abs(diff(camYaw(), rootYaw()))
	return r
end
local CENTER_STEP = 120 / 60 -- deg per frame at the top recenter speed

-- 1. walking toward a world-fixed direction 36.87 deg right of the camera look: the camera turns toward it (capped),
-- orbiting the focus, and settles behind me (A23-65)
local FWD_RIGHT = vec(0.6, 0, -0.8)
local FWD_YAW = -math.deg(math.atan2(0.6, 0.8))
reset()
local d0, y0 = dist(), camYaw()
humanoid.MoveDirection = FWD_RIGHT
frame(1)
local y1 = camYaw()
check(y1 < y0 and math.abs(y1 - y0) <= 45 / 60 + 1e-6 and math.abs(y1 - y0) > 0.2,
	"walking forward-right turns the camera right, within the 45 deg/s cap", show({ y0, y1 }))
check(math.abs(dist() - d0) < 1e-6 and math.abs(camera.CFrame.LookVector.Y - START_TILT) < 1e-6,
	"it orbits the focus: same distance, same downward tilt", show({ dist(), d0 }))
frame(480)
local y2 = camYaw()
check(math.abs(y2 - FWD_YAW) <= 6 + 1e-6 and y2 >= FWD_YAW - 1e-6,
	"after a while it settles behind me (within the 6 deg dead zone, no overshoot)", y2)

-- 2. (e) standing / backing up toward the camera: never turns, not while backing and not after the stop either
reset()
frame(60)
check(still(), "standing still: the camera stays", camYaw())
humanoid.MoveDirection = vec(0, 0, 1)
frame(60)
check(still(), "walking toward the camera (backing up): never spins", camYaw())
humanoid.MoveDirection = vec(0.6, 0, 0.8) -- back and to the right (walk . look = -0.8)
frame(60)
check(still(), "backing up diagonally: never spins", camYaw())
humanoid.MoveDirection = vec(0.9, 0, 0.436) -- mostly sideways, a little back (walk . look = -0.44 < BackDot -0.35)
frame(60)
check(still(), "a walk more than ~110 deg off the look counts as backing up", camYaw())
local backStop = stopAndWatch(3)
check(backStop.FirstMove == math.huge and still(), "(e) after backing up and stopping: no 180 deg spin to my back",
	show({ backStop.FirstMove, camYaw(), rootYaw() }))
reset()
local _, sTurn = hold(0, -1, 1) -- S held 1 s
local sStop = stopAndWatch(3)
check(math.abs(sTurn) < 1e-9 and sStop.FirstMove == math.huge and still(),
	"(e) holding S then letting go: the camera never turns", show({ sTurn, sStop.FirstMove, camYaw() }))
reset()
local _, sdTurn = hold(0.7071, -0.7071, 1) -- S+D held 1 s (135 deg off the look)
local sdStop = stopAndWatch(3)
check(math.abs(sdTurn) < 1e-9 and sdStop.FirstMove == math.huge and still(),
	"(e) holding S+D then letting go: the camera never turns", show({ sdTurn, sdStop.FirstMove, camYaw() }))

-- 3. A23-74 walking: sidesteps turn too, and the cap depends smoothly on the angle off the camera look
reset()
humanoid.MoveDirection = vec(1, 0, 0) -- a plain sidestep to the right (D / the stick to the right)
frame(1)
local side1 = camYaw()
check(side1 < -0.2 and math.abs(side1) <= 16 / 60 + 1e-6, "a sidestep right turns the camera right, at most 16 deg/s", side1)
reset()
humanoid.MoveDirection = vec(-1, 0, 0)
frame(1)
check(camYaw() > 0.2, "a sidestep left turns it left", camYaw())
reset()
humanoid.MoveDirection = vec(0.97, 0, 0.24) -- sideways, a little back (walk . look = -0.24, above BackDot)
frame(1)
check(camYaw() < -0.2, "sideways and a little back still turns it", camYaw())
reset()
humanoid.MoveDirection = vec(math.sin(math.rad(20)), 0, -math.cos(math.rad(20))) -- 20 deg right of the look
frame(1)
local near = math.abs(camYaw()) * 60
check(near > 18 and near <= math.deg(WALK / 55) + 1e-6,
	"a walk 20 deg off the look: above the 16 deg/s side cap, at most speed / 55 studs (20.8 deg/s)", near)
local capRows, prevCap, monotone, maxJump = {}, nil, true, 0
for deg = 0, 110 do
	local c = math.deg(FOLLOW.Cap(math.rad(deg), FOLLOW.Rate, FOLLOW.SideRate))
	capRows[deg] = c
	if prevCap then
		if c > prevCap + 1e-9 then monotone = false end
		maxJump = math.max(maxJump, math.abs(c - prevCap))
	end
	prevCap = c
end
check(math.abs(capRows[0] - 45) < 1e-6 and math.abs(capRows[20] - 45) < 1e-6,
	"the cap: the full 45 deg/s within 20 deg of the camera look", show({ capRows[0], capRows[20] }))
check(capRows[37] <= 21 and capRows[45] <= 18 and math.abs(capRows[60] - 16) < 1e-6 and math.abs(capRows[110] - 16) < 1e-6,
	"the cap: <= 21 deg/s at 37 deg, <= 18 at 45, the 16 deg/s side cap from 60 deg to the backpedal limit",
	show({ capRows[37], capRows[45], capRows[60], capRows[110] }))
check(monotone and maxJump < 2.5, "the cap falls smoothly (never rises, no step bigger than 2.5 deg/s per deg)",
	show({ monotone, maxJump }))
-- held keys are camera-relative: W already walks along the camera look; a held diagonal / side input never lines up,
-- so the turn never ends - the low cap makes that a wide arc (radius = walked / turned), not a tight circle
reset()
local _, wTurn = hold(0, 1, 1)
check(math.abs(wTurn) < 1e-9, "holding W: already behind me, the camera stays", wTurn)
reset()
local dWalk, dTurn, dMax = hold(1, 0, 2)
check(dTurn > 25 and dTurn <= 32 + 1e-4 and dMax <= 16 / 60 + 1e-6 and radius(dWalk, dTurn) >= 55,
	"holding D for 2 s: the camera keeps turning right in a wide arc (radius >= 55 studs)",
	show({ turned = dTurn, radius = radius(dWalk, dTurn) }))
reset()
local wdWalk, wdTurn = hold(0.7071, 0.7071, 3)
check(wdTurn > 0 and radius(wdWalk, wdTurn) >= 55, "(d) holding W+D for 3 s: a wide arc, radius >= 55 studs (>= 50 required)",
	show({ turned = wdTurn, radius = radius(wdWalk, wdTurn) }))
for _, deg in { 37, 60, 100 } do
	reset()
	local sw, st = hold(math.sin(math.rad(deg)), math.cos(math.rad(deg)), 3)
	check(st > 0 and radius(sw, st) >= 55 - 1e-3, "(d) a stick held " .. deg .. " deg off forward: radius >= 55 studs",
		show({ turned = st, radius = radius(sw, st) }))
end
-- (2) review A23-74: a stick held 18-34 deg off made 35-48-stud circles (the 45 deg/s cap). Sweep 0..110 deg (the
-- backpedal limit is ~110.5 deg) in 5 deg steps: every held angle walks a circle of radius >= 50 studs
local sweepMin, sweepMinDeg, sweepTurning = math.huge, -1, 0
for deg = 0, 110, 5 do
	reset()
	local sw, st = hold(math.sin(math.rad(deg)), math.cos(math.rad(deg)), 3)
	local r = radius(sw, st)
	if math.abs(st) > 1e-9 then sweepTurning += 1 end
	if r < sweepMin then sweepMin, sweepMinDeg = r, deg end
	check(st >= 0 and r >= 50, "(2) a stick held " .. deg .. " deg off forward: a circle of radius >= 50 studs",
		show({ turned = st, radius = r }))
end
check(sweepTurning >= 20 and sweepMin >= 55 - 1e-3,
	"(2) the sweep: the camera follows from 10 deg on, and no angle circles tighter than the 55-stud MinRadius",
	show({ turning = sweepTurning, minRadius = sweepMin, at = sweepMinDeg }))
-- a half-pushed stick walks at half speed: the cap halves with it (else 27-stud circles)
reset()
local halfWalk, halfTurn = hold(math.sin(math.rad(25)), math.cos(math.rad(25)), 3, nil, 0.5)
check(halfTurn > 0 and radius(halfWalk, halfTurn) >= 50, "(2) a half-pushed stick 25 deg off: radius >= 50 studs too",
	show({ turned = halfTurn, radius = radius(halfWalk, halfTurn) }))
-- a slower walk (WalkSpeed 12): the cap follows my Humanoid's WalkSpeed
reset()
humanoid.WalkSpeed = 12
local slowWalk, slowTurn = hold(math.sin(math.rad(25)), math.cos(math.rad(25)), 3)
check(slowTurn > 0 and radius(slowWalk, slowTurn) >= 50, "(2) a slower walk (WalkSpeed 12) 25 deg off: radius >= 50 studs",
	show({ turned = slowTurn, radius = radius(slowWalk, slowTurn) }))
-- a faster walk (a pet bonus, WalkSpeed 26) still turns faster than at 20 (the cap scales up, never a fixed crawl)
reset()
local baseWalk, baseTurn = hold(math.sin(math.rad(25)), math.cos(math.rad(25)), 3)
reset()
humanoid.WalkSpeed = 26
local fastWalk, fastTurn = hold(math.sin(math.rad(25)), math.cos(math.rad(25)), 3)
check(fastTurn > baseTurn + 5 and radius(fastWalk, fastTurn) >= 50,
	"(2) a faster walk (WalkSpeed 26) 25 deg off: turns faster than at 20, radius still >= 50 studs",
	show({ turned = fastTurn, base = baseTurn, radius = radius(fastWalk, fastTurn), baseRadius = radius(baseWalk, baseTurn) }))
-- phone: walking with the left thumbstick drives the follow (the stick sinks its touch: processed)
reset()
humanoid.MoveDirection = vec(1, 0, 0) -- the stick pushed right
local stick = { UserInputType = "Touch", Position = vec(150, 450, 0) }
input.InputBegan:Fire(stick, true)
input.InputChanged:Fire(stick, true)
frame(1)
check(camYaw() < -0.2, "phone: walking with the left thumbstick drives the follow", camYaw())
local stickStop = stopAndWatch(1.2, nil, function(t) if t < 0.1 then input.InputChanged:Fire(stick, true) end end)
check(stickStop.Off <= 8, "phone: letting go of the thumbstick brings the camera behind me", show(stickStop))
input.InputEnded:Fire(stick, true)

-- 4. (a) / (b) A23-74 recenter: after a held side / diagonal walk, the camera comes round behind my head on the stop
reset()
hold(1, 0, 2) -- D 2 s: my body faces 90 deg right of the camera look the whole time (a side view)
local dStop = stopAndWatch(3, 1.2)
check(math.abs(dStop.Start) > 80, "holding D: a side view while walking (my body ~90 deg off the camera look)", dStop.Start)
check(dStop.OffAt and dStop.OffAt <= 8, "(a) D 2 s, let go: within 1.2 s the camera is within 8 deg of my facing", show(dStop))
check(dStop.FirstMove >= 0.25 - 1e-6 and dStop.FirstMove <= 0.25 + 3 * DT,
	"(a) it waits 0.25 s after the stop, then starts", dStop.FirstMove)
check(dStop.MaxStep <= CENTER_STEP + 1e-6 and dStop.FirstStep <= CENTER_STEP / 2,
	"(a) eased: at most 120 deg/s, and it starts slow (ease in)", show(dStop))
check(not dStop.Overshoot and dStop.Off <= 1 + 1e-6, "(a) it ends behind me (within 1 deg) without overshoot", show(dStop))
check(dStop.DistDrift < 1e-6 and dStop.TiltDrift < 1e-6, "(a) the recenter orbits the focus: same distance, same tilt",
	show(dStop))
local settled = camYaw()
frame(120)
check(math.abs(diff(camYaw(), settled)) < 1e-9, "once behind me it stays still", camYaw())
faceYaw(rootYaw() - 4)
frame(120)
check(math.abs(diff(camYaw(), settled)) < 1e-9, "the dead zone: a 4 deg turn of my body while standing leaves it still",
	show({ camYaw(), rootYaw() }))
faceYaw(rootYaw() - 15)
frame(90)
check(math.abs(diff(camYaw(), rootYaw())) <= 1 + 1e-6, "beyond the dead zone (my body turned 15 deg more) it comes round again",
	show({ camYaw(), rootYaw() }))
reset()
hold(-1, 0, 2) -- A 2 s
local aStop = stopAndWatch(1.2, 1.2)
check(aStop.Start < -80 and aStop.OffAt <= 8 and not aStop.Overshoot, "(a) A 2 s, let go: comes round the other way too", show(aStop))
reset()
hold(0.7071, 0.7071, 2) -- W+D 2 s
local wdStop = stopAndWatch(3, 1.2)
check(math.abs(wdStop.Start) > 40, "holding W+D: my body ~45 deg off the camera look", wdStop.Start)
check(wdStop.OffAt and wdStop.OffAt <= 8 and not wdStop.Overshoot and wdStop.Off <= 1 + 1e-6,
	"(b) W+D 2 s, let go: within 1.2 s within 8 deg of my facing, then behind me", show(wdStop))
-- a short stop (< 0.25 s, e.g. switching keys) never recenters
reset()
hold(1, 0, 1)
humanoid.MoveDirection = vec(0, 0, 0)
local beforeTap = camYaw()
frame(12) -- 0.2 s
check(math.abs(diff(camYaw(), beforeTap)) < 1e-9, "a stop shorter than 0.25 s: no recenter", camYaw())
-- slower with 'Screen shake' off / Reduced Motion
reset()
hold(1, 0, 2)
W.Settings.Shake = false
local slowStop = stopAndWatch(3, 1.2)
check(slowStop.MaxStep <= 60 / 60 + 1e-6 and slowStop.OffAt > 8 and slowStop.Off <= 1 + 1e-6,
	"'Screen shake' off: the recenter is slower (<= 60 deg/s) but still ends behind me", show(slowStop))
reset()
hold(1, 0, 2)
gui.ReducedMotionEnabled = true
local reducedStop = stopAndWatch(3)
check(reducedStop.MaxStep <= 60 / 60 + 1e-6 and reducedStop.Off <= 1 + 1e-6, "Roblox Reduced Motion: the slow recenter too",
	show(reducedStop))

-- 5. (c) holds: a hand turn holds the follow 1.5 s; while standing it keeps my own view; my swing holds 0.5 s
reset()
humanoid.MoveDirection = FWD_RIGHT
input.RightDown = true
frame(30)
check(still(), "while the right button is down: no follow (Roblox's right drag owns the camera)")
input.RightDown = false
frame(60) -- 1.0 s after the drag
check(still(), "1.0 s after the right drag: still no follow")
frame(36) -- 1.6 s
check(camYaw() < -0.2, "1.5 s after the right drag: the follow comes back", camYaw())
reset()
hold(1, 0, 2)
local dragStop = stopAndWatch(4, nil, function(t) input.RightDown = t > 0.1 and t < 0.3 end)
check(dragStop.FirstMove == math.huge, "(c) a right drag right after the stop: no recenter, during the hold or after it",
	show(dragStop))
local reArm = { hold(1, 0, 0.5) }
local reStop = stopAndWatch(1.2, 1.2)
check(reStop.OffAt and reStop.OffAt <= 8, "the next walk and stop recenters again", show({ reArm[2], reStop.OffAt }))
reset()
hold(1, 0, 2, function(i) input.RightDown = i > 90 end) -- the right drag in the last 0.5 s of the walk
input.RightDown = false
local lateStop = stopAndWatch(4)
check(lateStop.FirstMove == math.huge, "(c) a right drag within 1.5 s before the stop: no recenter (my own view)",
	show(lateStop))
reset()
hold(1, 0, 3, function(i) input.RightDown = i <= 18 end) -- a right drag at the start of a 3 s walk
input.RightDown = false
local earlyStop = stopAndWatch(1.2, 1.2)
check(earlyStop.OffAt and earlyStop.OffAt <= 8, "a right drag long before the stop (> 1.5 s): the recenter still runs",
	show(earlyStop))
reset()
hold(1, 0, 2)
local touch = { UserInputType = "Touch", Position = vec(800, 300, 0) }
local touchStop = stopAndWatch(4, nil, function(t)
	if math.abs(t - 0.1) < DT / 2 then input.InputBegan:Fire(touch, false) end
	if t > 0.1 and t < 0.3 then input.InputChanged:Fire(touch, false) end
	if math.abs(t - 0.3) < DT / 2 then input.InputEnded:Fire(touch, false) end
end)
check(touchStop.FirstMove == math.huge, "(c) phone: a finger drag on the camera side while standing keeps my view",
	show(touchStop))
reset()
humanoid.MoveDirection = FWD_RIGHT
local right = { UserInputType = "Touch", Position = vec(800, 300, 0) }
input.InputBegan:Fire(right, false)
input.InputChanged:Fire(right, false)
frame(30)
check(still(), "a finger drag on the camera side holds the follow")
input.InputEnded:Fire(right, false)
reset()
humanoid.MoveDirection = FWD_RIGHT
local left = { UserInputType = "Touch", Position = vec(150, 450, 0) }
input.InputBegan:Fire(left, false)
input.InputChanged:Fire(left, false)
frame(1)
check(camYaw() < -0.2, "a finger on the move stick (left side) does not hold the follow", camYaw())
input.InputEnded:Fire(left, false)
reset()
humanoid.MoveDirection = FWD_RIGHT
input.InputChanged:Fire({ UserInputType = "Pad", KeyCode = "Thumb2", Position = vec(0.8, 0, 0) }, false)
frame(30)
check(still(), "the right stick holds the follow")
reset()
humanoid.MoveDirection = FWD_RIGHT
fxSignal:Fire("Swing", { UserId = 7 })
frame(24) -- 0.4 s
check(still(), "0.4 s after my swing: no follow (FaceTarget never whips the camera)")
frame(9) -- 0.55 s
check(camYaw() < -0.2, "0.5 s after my swing: follows again", camYaw())
for _, kind in { "Release", "Skill" } do
	reset()
	humanoid.MoveDirection = FWD_RIGHT
	fxSignal:Fire(kind, { UserId = 7 })
	frame(12)
	check(still(), "my " .. kind .. " holds the follow too")
end
reset()
humanoid.MoveDirection = FWD_RIGHT
fxSignal:Fire("Swing", { UserId = 99 })
frame(1)
check(camYaw() < -0.2, "another player's swing does not hold my camera")
reset()
hold(1, 0, 2)
local swingStop = stopAndWatch(2.5, 1.8, function(t)
	if math.abs(t - 0.2) < DT / 2 then fxSignal:Fire("Swing", { UserId = 7 }) end
end)
check(swingStop.FirstMove >= 0.2 + 0.5 - 2 * DT, "(c) my swing 0.2 s after the stop: no recenter for 0.5 s after it", show(swingStop))
check(swingStop.OffAt and swingStop.OffAt <= 8, "after the swing hold the recenter runs (within 8 deg 1.1 s after it)",
	show(swingStop))
reset()
hold(1, 0, 2)
local otherStop = stopAndWatch(1.2, 1.2, function(t)
	if math.abs(t - 0.2) < DT / 2 then fxSignal:Fire("Swing", { UserId = 99 }) end
end)
check(otherStop.OffAt and otherStop.OffAt <= 8, "another player's swing does not hold my recenter", show(otherStop))

-- 6. (c) switches and states: no follow and no recenter
reset()
humanoid.MoveDirection = FWD_RIGHT
W.Settings.Cam = "Free"
frame(30)
check(still(), "Settings Camera = Free: no follow")
local freeStop = stopAndWatch(3)
check(freeStop.FirstMove == math.huge, "(c) Settings Camera = Free: no recenter after the walk", show(freeStop))
reset()
humanoid.MoveDirection = FWD_RIGHT
W.Settings.Cam = nil -- a new player: no camera setting saved yet
frame(30)
check(still(), "no camera setting yet: the default is Free (user 10/08) - no follow")
reset()
humanoid.MoveDirection = FWD_RIGHT
W.Settings.Shake = false
frame(1)
local slowStep = math.abs(camYaw())
reset()
humanoid.MoveDirection = FWD_RIGHT
frame(1)
local fastStep = math.abs(camYaw())
check(slowStep > 0.1 and slowStep < fastStep - 0.05 and slowStep <= 25 / 60 + 1e-6,
	"'Screen shake' off: the follow turns slower", show({ slowStep, fastStep }))
reset()
humanoid.MoveDirection = vec(1, 0, 0)
W.Settings.Shake = false
frame(1)
local slowSide = math.abs(camYaw())
check(slowSide > 0.1 and slowSide <= 10 / 60 + 1e-6, "'Screen shake' off, sideways: slower still (10 deg/s)", slowSide)
reset()
humanoid.MoveDirection = FWD_RIGHT
gui.ReducedMotionEnabled = true
frame(1)
local reducedStep = math.abs(camYaw())
check(reducedStep > 0.1 and reducedStep < fastStep - 0.05, "Roblox Reduced Motion: the slow rate too", show({ reducedStep, fastStep }))
reset()
humanoid.MoveDirection = FWD_RIGHT
registry.Panels.Open = true
frame(30)
check(still(), "a window open: no follow")
reset()
hold(1, 0, 2)
registry.Panels.Open = true
local panelStop = stopAndWatch(2)
check(panelStop.FirstMove == math.huge, "(c) a window open after the walk: no recenter", show(panelStop))
registry.Panels.Open = false
local panelAfter = stopAndWatch(1.2, 1.2)
check(panelAfter.OffAt and panelAfter.OffAt <= 8, "the window closed: it comes round behind me", show(panelAfter))
reset()
humanoid.MoveDirection = FWD_RIGHT
camera.CameraType = "Scriptable"
frame(30)
check(still(), "a scripted camera (the opening): no follow")
reset()
hold(1, 0, 2)
camera.CameraType = "Scriptable"
local scriptStop = stopAndWatch(2)
check(scriptStop.FirstMove == math.huge, "(c) a scripted camera: no recenter", show(scriptStop))
reset()
humanoid.MoveDirection = FWD_RIGHT
input.MouseBehavior = "LockCenter"
frame(30)
check(still(), "shift lock: no follow (it turns me itself)")
reset()
hold(1, 0, 2)
input.MouseBehavior = "LockCenter"
local lockStop = stopAndWatch(2)
check(lockStop.FirstMove == math.huge, "shift lock: no recenter", show(lockStop))
reset()
humanoid.MoveDirection = FWD_RIGHT
camera.Focus.Position = camera.CFrame.Position + vec(0, 0, -0.5)
frame(30)
check(still(), "first person: no follow")
reset()
hold(1, 0, 2)
camera.Focus.Position = camera.CFrame.Position + vec(0, 0, -0.5)
local fpStop = stopAndWatch(2)
check(fpStop.FirstMove == math.huge, "first person: no recenter", show(fpStop))
reset()
hold(1, 0, 2)
humanoid.Health = 0
local deadStop = stopAndWatch(2)
check(deadStop.FirstMove == math.huge, "dead: no recenter", show(deadStop))

-- 7. (1) review A23-74: Roblox's own keyboard / trackpad camera turn is a hand turn (a held Right arrow turned only
-- 14 deg and snapped back: the recenter pulled against it). Only CameraFollow's turn is measured
local function keyHold(key, seconds, deg)
	local ours = 0
	for _ = 1, math.floor(seconds * 60 + 0.5) do
		input.Keys[key] = true
		robloxTurn(deg * DT)
		local before = camYaw()
		frame(1)
		ours += math.abs(diff(camYaw(), before))
	end
	input.Keys[key] = nil
	return ours
end
reset()
local rightOurs = keyHold("Right", 0.5, -KEY_TURN)
check(rightOurs < 1e-9 and math.abs(diff(camYaw(), -60)) < 1e-6,
	"(1) the Right arrow held 0.5 s while standing: Roblox's keyboard turn goes the full 60 deg, never pulled back",
	show({ ours = rightOurs, yaw = camYaw() }))
local rightAfter = stopAndWatch(3)
check(rightAfter.FirstMove == math.huge and math.abs(diff(camYaw(), -60)) < 1e-6,
	"(1) after letting go of the Right arrow: my own view is kept (no snap back) until the next walk", show(rightAfter))
local _, rightReTurn = hold(1, 0, 0.5)
local rightReStop = stopAndWatch(1.4, 1.4)
check(rightReStop.OffAt and rightReStop.OffAt <= 8, "(1) the next walk and stop recenters again",
	show({ rightReTurn, rightReStop.OffAt }))
for _, key in { "Left", "Comma", "Period" } do
	reset()
	local ours = keyHold(key, 0.4, KEY_TURN)
	local after = stopAndWatch(2)
	check(ours < 1e-9 and after.FirstMove == math.huge, "(1) " .. key .. " held while standing: a hand turn, kept",
		show({ ours = ours, firstMove = after.FirstMove, yaw = camYaw() }))
end
reset()
local _, arrowWalk = hold(0.7071, 0.7071, 1.9, function(i)
	if i <= 30 then input.Keys.Left = true; robloxTurn(KEY_TURN * DT) else input.Keys.Left = nil end
end)
check(math.abs(arrowWalk) < 1e-9, "(1) W+D with the Left arrow for 0.5 s: no follow while it turns and for the 1.4 s after", arrowWalk)
-- a quick Comma / Period tap that begins and ends between two frames (Roblox snaps the camera; processed or not)
for _, tap in { { "Comma", false }, { "Period", true } } do
	reset()
	hold(1, 0, 2) -- D 2 s: my body ~90 deg right of the camera look
	local tapStop = stopAndWatch(3, nil, function(t)
		if math.abs(t - 0.1) < DT / 2 then
			input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = tap[1] }, tap[2])
			robloxTurn(-45)
		end
	end)
	check(tapStop.FirstMove == math.huge, "(1) a " .. tap[1] .. " tap between frames (processed " .. tostring(tap[2])
		.. ") right after the stop: my own view, no recenter", show(tapStop))
end
-- a two-finger trackpad pan (UserInputService.PointerAction) turns Roblox's camera too
reset()
hold(1, 0, 2)
local panStop = stopAndWatch(3, nil, function(t)
	if t > 0.05 and t < 0.4 then
		input.PointerAction:Fire(0, vec(-3, 0, 0), 0, false)
		robloxTurn(-40 * DT)
	end
end)
check(panStop.FirstMove == math.huge, "(1) a trackpad pan right after the stop: my own view, no recenter", show(panStop))
reset()
hold(1, 0, 2)
local wheelStop = stopAndWatch(1.2, 1.2, function(t)
	if t > 0.05 and t < 0.4 then input.PointerAction:Fire(1, vec(0, 0, 0), 0, false) end
end)
check(wheelStop.OffAt and wheelStop.OffAt <= 8, "(1) a wheel / pinch zoom (no pan) is not a hand turn: the recenter runs",
	show(wheelStop))
-- typing a comma / period in a text box (chat) is no hand turn: the recenter runs once the box closes
reset()
hold(1, 0, 2)
local typedStop = stopAndWatch(2, 1.9, function(t)
	if t < 0.5 then
		input.TextBox = {}
		input.Keys.Comma = t > 0.1 and t < 0.3
		if math.abs(t - 0.2) < DT / 2 then input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = "Period" }, true) end
	else
		input.TextBox, input.Keys.Comma = nil, nil
	end
end)
check(typedStop.OffAt and typedStop.OffAt <= 8, "(1) typing ',' / '.' in a text box is no hand turn: the recenter runs after",
	show(typedStop))
reset()
hold(1, 0, 2)
local otherKeyStop = stopAndWatch(1.2, 1.2, function(t)
	if math.abs(t - 0.1) < DT / 2 then input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = "E" }, false) end
end)
check(otherKeyStop.OffAt and otherKeyStop.OffAt <= 8, "(1) other keys (E right after the stop) are no hand turn",
	show(otherKeyStop))

-- 8. (3) Roblox's Follow camera (touch: DevTouchCameraMode, a PC: DevComputerCameraMode; UserChoice = the player's
-- Roblox setting, Default = Follow on touch / Classic on a PC): while it is active WalkTurn stays off (never two turns)
local function sideStep(setup)
	reset()
	setup()
	humanoid.MoveDirection = vec(1, 0, 0)
	frame(1)
	return camYaw() < -0.2
end
check(sideStep(function() input.TouchEnabled = true end), "(3) a phone on Classic (after Start): the walking turn is ours")
check(not sideStep(function() input.TouchEnabled = true; player.DevTouchCameraMode = DTM.Follow end),
	"(3) a phone on Roblox's Follow camera: no second walking turn")
check(not sideStep(function() input.TouchEnabled = true; player.DevTouchCameraMode = DTM.UserChoice end),
	"(3) a phone on UserChoice with Roblox's Default (= Follow on touch): no second walking turn")
check(sideStep(function()
	input.TouchEnabled = true; player.DevTouchCameraMode = DTM.UserChoice
	userGame.TouchCameraMovementMode = { Name = "Classic" }
end), "(3) a phone on UserChoice whose player picked Classic: the walking turn is ours")
check(sideStep(function() input.TouchEnabled = false end), "(3) a PC on UserChoice with Roblox's Default (= Classic): ours")
check(not sideStep(function() userGame.ComputerCameraMovementMode = { Name = "Follow" } end),
	"(3) a PC player who picked Roblox's Follow camera: no second walking turn")
check(not sideStep(function() player.DevComputerCameraMode = DCM.Follow end),
	"(3) a PC with DevComputerCameraMode Follow: no second walking turn")
reset()
input.TouchEnabled, player.DevTouchCameraMode = true, DTM.Follow
hold(1, 0, 2)
local followStop = stopAndWatch(1.2, 1.2)
check(followStop.OffAt and followStop.OffAt <= 8, "(3) Roblox's Follow camera on: the standing recenter still runs",
	show(followStop))
-- the set may be refused (a locked property): no error, and RobloxFollows keeps WalkTurn off instead
reset()
rawset(player, "DevTouchCameraMode", nil)
setmetatable(player, { __index = { DevTouchCameraMode = DTM.UserChoice }, __newindex = function(t, k, v)
	if k == "DevTouchCameraMode" then error("locked") end
	rawset(t, k, v)
end })
local okSet, setResult = pcall(FOLLOW.TouchClassic)
input.TouchEnabled = true
humanoid.MoveDirection = vec(1, 0, 0)
frame(1)
check(okSet and setResult == false and still(),
	"(3) the Classic switch refused: no error, and the walking turn stays off under Roblox's Follow camera",
	show({ okSet, setResult, camYaw() }))
setmetatable(player, nil)
reset()
player.DevTouchCameraMode = DTM.Orbital
check(FOLLOW.TouchClassic() == false and player.DevTouchCameraMode == DTM.Orbital,
	"(3) only UserChoice / Follow are switched (another explicit mode is left alone)", player.DevTouchCameraMode.Name)
player.DevTouchCameraMode = DTM.Follow
check(FOLLOW.TouchClassic() == true and player.DevTouchCameraMode == DTM.Classic, "(3) Follow is switched to Classic too",
	player.DevTouchCameraMode.Name)

-- 9. (4) review A23-74: a long frame (a 0.5 s hitch) turns as if it were 1/20 s (it jumped the recenter 60 deg)
local function hitch(dt)
	W.Clock += dt
	local m = humanoid.MoveDirection
	if W.AutoRotate and m.Magnitude >= 0.2 then face(m) end
	step.Fn(dt)
end
reset()
hold(1, 0, 2)
humanoid.MoveDirection = vec(0, 0, 0)
frame(30) -- 0.5 s after the stop: the recenter runs at full speed
local beforeHitch = camYaw()
hitch(0.5)
local centerHitch = math.abs(diff(camYaw(), beforeHitch))
check(centerHitch > 0.5 and centerHitch <= 120 / 20 + 1e-6,
	"(4) a 0.5 s hitch during the recenter turns at most 6 deg (1/20 s at 120 deg/s), not 60", centerHitch)
reset()
hold(1, 0, 2)
humanoid.MoveDirection = vec(0, 0, 0)
frame(15) -- 0.25 s: the next frame starts the recenter
local beforeFirst = camYaw()
hitch(0.5)
local firstHitch = math.abs(diff(camYaw(), beforeFirst))
check(firstHitch <= 120 / 20 + 1e-6, "(4) a hitch on the recenter's first frame: at most 6 deg too", firstHitch)
reset()
hold(1, 0, 0.5)
humanoid.MoveDirection = camRelative(1, 0)
local beforeWalkHitch = camYaw()
hitch(0.5)
local walkHitch = math.abs(diff(camYaw(), beforeWalkHitch))
check(walkHitch > 0.1 and walkHitch <= 16 / 20 + 1e-6,
	"(4) a 0.5 s hitch while walking sideways turns at most 0.8 deg (1/20 s at 16 deg/s), not 8", walkHitch)
local function r1(x) return x and math.floor(x * 10 + 0.5) / 10 or -1 end
print(string.format("CAMERA_FOLLOW_NUMBERS dRadius=%s wdRadius=%s capAt37=%s capAt45=%s dStart=%s dOffAt1.2s=%s "
	.. "dFirstMove=%.2f dMaxDegPerS=%s wdStart=%s wdOffAt1.2s=%s slowOffAt1.2s=%s swingFirstMove=%.2f "
	.. "sweepMinRadius=%s sweepMinAt=%d halfStickRadius=%s walk12Radius=%s rightArrowOurs=%s centerHitchDeg=%s "
	.. "walkHitchDeg=%.2f",
	r1(radius(dWalk, dTurn)), r1(radius(wdWalk, wdTurn)), r1(capRows[37]), r1(capRows[45]), r1(dStop.Start), r1(dStop.OffAt),
	dStop.FirstMove, r1(dStop.MaxStep * 60), r1(wdStop.Start), r1(wdStop.OffAt), r1(slowStop.OffAt),
	swingStop.FirstMove, r1(sweepMin), sweepMinDeg, r1(radius(halfWalk, halfTurn)), r1(radius(slowWalk, slowTurn)),
	r1(rightOurs), r1(centerHitch), walkHitch))
print("CAMERA_FOLLOW_SUMMARY checks=" .. checks .. " failed=" .. failed)
