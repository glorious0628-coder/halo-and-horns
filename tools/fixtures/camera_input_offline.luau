-- Production CameraFollow + input/lifecycle doubles. No physical mouse or Roblox camera simulation.
-- A23-51 (user 2026-10-06): right drag turns the camera (Roblox's default camera, never touched by CameraFollow); a left
-- drag never turns it; a left press on the world = one attack on the press, never repeated while held or dragged.
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function signal()
	local rows, s = {}, {}
	function s:Connect(fn)
		local row = { Fn = fn, Connected = true }; table.insert(rows, row)
		return { Disconnect = function() row.Connected = false end }
	end
	function s:Fire(...)
		for _, row in table.clone(rows) do if row.Connected then row.Fn(...) end end
	end
	return s
end
local function vec(x, y, z) return { X = x, Y = y, Z = z } end
local function fixture()
	local q, frameSteps = {}, {}
	-- "unchanged" stays unless production code writes the camera transform (it never may)
	local camera = { CameraType = "Custom", CameraSubject = nil, CFrame = "unchanged" }
	local workspace = { CurrentCamera = camera, Signal = signal() }
	function workspace:GetPropertyChangedSignal() return self.Signal end
	camera.Signals = { CameraType = signal(), CameraSubject = signal() }
	function camera:GetPropertyChangedSignal(name) return self.Signals[name] end
	local player = { CharacterAdded = signal(), CharacterRemoving = signal(), Ready = true }
	function player:GetAttribute(name) return name == "DataLoaded" and self.Ready end
	local gui = { MenuIsOpen = false, MenuOpened = signal() }
	local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal(),
		MouseBehavior = "Default", LeftDown = false, RightDown = false }
	function input:GetFocusedTextBox() return self.TextBox end
	function input:IsMouseButtonPressed(kind)
		if kind == "LMB" then return self.LeftDown == true end
		return kind == "RMB" and self.RightDown == true
	end
	input.Keys = {}
	function input:IsKeyDown(key) return self.Keys[key] == true end
	local run = {}
	function run:BindToRenderStep(name, priority, fn) frameSteps[name] = { Priority = priority, Fn = fn } end
	local services = { Players = { LocalPlayer = player }, UserInputService = input, GuiService = gui, RunService = run,
		ReplicatedStorage = { WaitForChild = function() return nil end } } -- the Fx hookup (A23-65) quietly fails here
	local registry = {}
	for _, name in { "FactionPicker", "ClassPicker", "Panels", "WorldMap" } do
		local module = { Open = false }; module.IsOpen = function() return module.Open end; registry[name] = module
	end
	local function newCharacter(parented, humanoid)
		local c = { Parented = parented, Humanoid = humanoid, AncestryChanged = signal(), ChildAdded = signal(), ChildRemoved = signal() }
		function c:IsDescendantOf() return self.Parented end
		function c:FindFirstChildOfClass() return self.Humanoid end
		return c
	end
	local humanoid = { IsA = function(_, name) return name == "Humanoid" end }
	player.Character = newCharacter(true, humanoid)
	local fn = assert(loadstring(SOURCE))
	setfenv(fn, setmetatable({
		game = { GetService = function(_, name) return assert(services[name]) end }, workspace = workspace,
		Instance = { new = function() local s = signal(); return { Event = s, Fire = function() s:Fire() end } end },
		Vector3 = { zero = vec(0, 0, 0) }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		task = { defer = function(cb) table.insert(q, cb) end, spawn = function(cb) cb() end },
		Enum = { CameraType = { Custom = "Custom" }, UserInputType = { MouseButton1 = "LMB", MouseButton2 = "RMB", MouseMovement = "Move", Touch = "Touch",
			Keyboard = "Keyboard" },
			MouseBehavior = { Default = "Default", LockCenter = "LockCenter", LockCurrentPosition = "LockCurrentPosition" },
			RenderPriority = { Camera = { Value = 200 } },
			KeyCode = { Thumbstick2 = "Thumb2", Left = "Left", Right = "Right", Comma = "Comma", Period = "Period" } },
	}, { __index = getfenv() }))
	local module = fn(); module.Init(registry); module.Start()
	local f = { Module = module, Input = input, Gui = gui, Registry = registry, Camera = camera, Player = player, Workspace = workspace,
		NewCharacter = newCharacter, Humanoid = humanoid, Clicks = 0, Steps = frameSteps }
	module.PrimaryClick:Connect(function() f.Clicks += 1 end)
	function f:Flush() while #q > 0 do local cb = table.remove(q, 1); cb() end end
	function f:RunSteps() for _, step in frameSteps do step.Fn(1 / 60) end end
	f.Cursor = { X = 400, Y = 300 }
	local function at() return { X = f.Cursor.X, Y = f.Cursor.Y, Z = 0 } end
	-- a left / right press, cursor moves (Position and Delta both move: a real mouse) and the release
	function f:Begin(kind, processed)
		kind = kind or "LMB"
		if kind == "LMB" then input.LeftDown = true elseif kind == "RMB" then input.RightDown = true end
		input.InputBegan:Fire({ UserInputType = kind, Position = at() }, processed == true)
	end
	function f:Move(x, y, processed)
		self.Cursor.X += x; self.Cursor.Y += y
		input.InputChanged:Fire({ UserInputType = "Move", Delta = { X = x, Y = y, Z = 0 }, Position = at() }, processed == true)
		self:RunSteps()
	end
	function f:End(kind, processed)
		kind = kind or "LMB"
		if kind == "LMB" then input.LeftDown = false elseif kind == "RMB" then input.RightDown = false end
		input.InputEnded:Fire({ UserInputType = kind, Position = at() }, processed == true)
		self:RunSteps()
	end
	f:Flush(); return f
end

local f = fixture()
check(f.Camera.CameraSubject == f.Humanoid, "initial subject attaches")
local stepNames = {}
for name in f.Steps do table.insert(stepNames, name) end
check(#stepNames == 1 and f.Steps.HHC_CameraFollow ~= nil and f.Steps.HHC_CameraFollow.Priority == 201,
	"one render step only: the A23-65 follow turn (after the camera); no left-mouse camera step")
-- left press = one attack, on the press
f:Begin(); check(f.Clicks == 1, "a left press attacks on the press (before the release)")
f:End(); check(f.Clicks == 1, "the release adds no second attack")
f:Begin(); for _ = 1, 20 do f:Move(15, 2) end; f:End()
check(f.Clicks == 2, "a left drag attacks once (the press) and never repeats while held")
check(f.Camera.CFrame == "unchanged", "a left drag never turns the camera")
f:Begin(); f:Move(300, -200); f:Move(-600, 400); f:End()
check(f.Clicks == 3 and f.Camera.CFrame == "unchanged", "a long left drag: one attack, camera untouched")
f:End(); check(f.Clicks == 3, "a release without a press never attacks")
-- right button: Roblox's default camera turns; CameraFollow neither attacks nor touches the camera
f:Begin("RMB"); for _ = 1, 10 do f:Move(20, 0) end; f:End("RMB")
check(f.Clicks == 3, "a right press / drag never attacks")
check(f.Camera.CFrame == "unchanged", "a right drag is left to Roblox's camera (CameraFollow writes nothing)")
f:Begin("RMB"); f:Begin(); f:Move(30, 0); f:End(); f:End("RMB")
check(f.Clicks == 4 and f.Camera.CFrame == "unchanged", "a left press while turning with the right button attacks once")
f:Begin("Touch"); f:End("Touch"); check(f.Clicks == 4, "touch is left to Roblox")
-- Roblox's keyboard camera turn (A23-74 review: read only to pause the follow turn): never an attack, never our camera write
for _, key in { "Left", "Right", "Comma", "Period" } do
	f.Input.Keys[key] = true
	f.Input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = key }, false)
	f:RunSteps()
	f.Input.Keys[key] = nil
	f.Input.InputEnded:Fire({ UserInputType = "Keyboard", KeyCode = key }, false)
end
check(f.Clicks == 4 and f.Camera.CFrame == "unchanged", "arrow / Comma / Period keys never attack and never write the camera")
-- presses that never attack
f:Begin(nil, true); f:End(); check(f.Clicks == 4, "a press on a GUI (processed) never attacks")
for _, name in { "FactionPicker", "ClassPicker", "Panels", "WorldMap" } do
	f.Registry[name].Open = true; f:Begin(); f:End(); check(f.Clicks == 4, name .. " open: a left press never attacks")
	f.Registry[name].Open = false
end
f.Gui.MenuIsOpen = true; f:Begin(); f:End(); check(f.Clicks == 4, "Roblox menu open: no attack")
f.Gui.MenuIsOpen = false
f.Input.TextBox = {}; f:Begin(); f:End(); check(f.Clicks == 4, "text focus blocks the attack")
f.Input.TextBox = nil
f.Player.Ready = false; f:Begin(); f:End(); check(f.Clicks == 4, "loading blocks the attack")
f.Player.Ready = true
f.Camera.CameraType = "Scriptable"; f:Begin(); f:End(); check(f.Clicks == 4, "scripted view blocks the attack")
f.Camera.CameraSubject = "cutscene"
f.Camera.Signals.CameraType:Fire(); f:Flush()
check(f.Camera.CameraType == "Scriptable" and f.Camera.CameraSubject == "cutscene", "a scripted camera keeps its own subject")
f.Camera.CameraType = "Custom"; f.Camera.Signals.CameraType:Fire(); f:Flush()
check(f.Camera.CameraSubject == f.Humanoid, "back to Custom: the humanoid is the subject again")
for _, behavior in { "LockCenter", "LockCurrentPosition" } do
	f.Input.MouseBehavior = behavior
	f:Begin(); f:Move(200, 40); f:End()
	f.Input.MouseBehavior = "Default"
end
check(f.Clicks == 6 and f.Camera.CFrame == "unchanged", "shift lock / locked cursor: one attack per press, camera untouched")
f:Begin(); check(f.Clicks == 7, "a normal press attacks again after the blocked ones")
f:End()
-- costume swap / respawn: the default camera follows the new humanoid
local old = f.Player.Character
f.Player.CharacterRemoving:Fire(old)
f:Begin(); f:End(); check(f.Clicks == 7, "no character (respawning): no attack")
local replacement = f.NewCharacter(false, nil); f.Player.Character = replacement; f.Player.CharacterAdded:Fire(replacement)
f:Flush(); check(f.Camera.CameraSubject == f.Humanoid, "wait for parent and humanoid")
replacement.Parented = true; replacement.AncestryChanged:Fire(); f:Flush()
check(f.Camera.CameraSubject == f.Humanoid, "no nil subject assigned during replication")
local nextHumanoid = { IsA = f.Humanoid.IsA }; replacement.Humanoid = nextHumanoid; replacement.ChildAdded:Fire(nextHumanoid); f:Flush()
check(f.Camera.CameraSubject == nextHumanoid, "late replicated humanoid becomes subject")
f:Begin(); f:End(); check(f.Clicks == 8, "the new character attacks with a left press")
check(f.Camera.CFrame == "unchanged", "lifecycle and presses alone never replace the camera transform")
print("CAMERA_INPUT_SUMMARY checks=" .. checks .. " failed=0")
