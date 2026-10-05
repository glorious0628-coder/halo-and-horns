-- Production module + input/lifecycle doubles. No physical mouse or Roblox camera simulation.
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
-- Minimal rigid transforms for numeric checks of the production rotateLook function.
local function vec(x, y, z) return { X = x, Y = y, Z = z } end
local function cross(a, b) return vec(a.Y*b.Z-a.Z*b.Y, a.Z*b.X-a.X*b.Z, a.X*b.Y-a.Y*b.X) end
local function unit(a)
	local n = math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z); return vec(a.X/n,a.Y/n,a.Z/n)
end
local frameMT = {}
local function frame(p, m)
	return setmetatable({ Position = p, M = m, LookVector = vec(-m[3], -m[6], -m[9]) }, frameMT)
end
frameMT.__mul = function(a, b)
	local m = {}
	for r=0,2 do for c=0,2 do
		m[r*3+c+1] = a.M[r*3+1]*b.M[c+1]+a.M[r*3+2]*b.M[c+4]+a.M[r*3+3]*b.M[c+7]
	end end
	local p=a.Position; local q=b.Position; local k=a.M
	return frame(vec(p.X+k[1]*q.X+k[2]*q.Y+k[3]*q.Z, p.Y+k[4]*q.X+k[5]*q.Y+k[6]*q.Z, p.Z+k[7]*q.X+k[8]*q.Y+k[9]*q.Z), m)
end
local CF = {}
function CF.new(p) return frame(p,{1,0,0,0,1,0,0,0,1}) end
function CF.lookAt(p, target)
	local look=unit(vec(target.X-p.X,target.Y-p.Y,target.Z-p.Z))
	local right=unit(cross(look,vec(0,1,0))); local up=cross(right,look)
	return frame(p,{right.X,up.X,-look.X,right.Y,up.Y,-look.Y,right.Z,up.Z,-look.Z})
end
function CF.Angles(x,y,z)
	assert(z==0,"fixture supports requested X/Y rotation only")
	local cx,sx,cy,sy=math.cos(x),math.sin(x),math.cos(y),math.sin(y)
	return frame(vec(0,0,0),{cy,0,sy,sx*sy,cx,-sx*cy,-cx*sy,sx,cx*cy})
end
local function fixture()
	local q, frameSteps = {}, {}
	local camera = { CameraType = "Custom", CameraSubject = nil, CFrame = "unchanged" }
	local workspace = { CurrentCamera = camera, Signal = signal() }
	function workspace:GetPropertyChangedSignal() return self.Signal end
	camera.Signals = { CameraType = signal(), CameraSubject = signal() }
	function camera:GetPropertyChangedSignal(name) return self.Signals[name] end
	local player = { CharacterAdded = signal(), CharacterRemoving = signal(), Ready = true }
	function player:GetAttribute(name) return name == "DataLoaded" and self.Ready end
	local gui = { MenuIsOpen = false, MenuOpened = signal() }
	local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal(),
		MouseBehavior = "Default" }
	function input:GetFocusedTextBox() return self.TextBox end
	function input:IsMouseButtonPressed() return self.RightDown == true end
	local run = {}
	function run:BindToRenderStep(name, priority, fn) frameSteps[name] = { Priority = priority, Fn = fn } end
	local services = { Players = { LocalPlayer = player }, UserInputService = input, GuiService = gui, RunService = run }
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
		CFrame = CF, Vector3 = { zero = vec(0,0,0) }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		task = { defer = function(cb) table.insert(q, cb) end },
		Enum = { CameraType = { Custom = "Custom" }, UserInputType = { MouseButton1 = "LMB", MouseButton2 = "RMB", MouseMovement = "Move", Touch = "Touch" },
			MouseBehavior = { Default = "Default", LockCenter = "LockCenter", LockCurrentPosition = "LockCurrentPosition" },
			RenderPriority = { Camera = { Value = 200 } } },
	}, { __index = getfenv() }))
	local module = fn(); module.Init(registry); module.Start()
	local f = { Module = module, Input = input, Gui = gui, Registry = registry, Camera = camera, Player = player, Workspace = workspace, NewCharacter = newCharacter, Humanoid = humanoid, Clicks = 0, Steps = frameSteps }
	module.PrimaryClick:Connect(function() f.Clicks += 1 end)
	function f:Flush() while #q > 0 do local cb = table.remove(q, 1); cb() end end
	-- A23 camera contract: MouseMovement Delta is zero with a free cursor in Studio, so the fixture
	-- reports Delta = 0 and moves only the cursor Position; production must measure Position differences.
	f.Cursor = { X = 400, Y = 300 }
	local function at() return { X = f.Cursor.X, Y = f.Cursor.Y, Z = 0 } end
	function f:Begin(kind, processed) input.InputBegan:Fire({ UserInputType = kind or "LMB", Position = at() }, processed == true) end
	function f:Move(x, y, processed)
		self.Cursor.X += x; self.Cursor.Y += y
		input.InputChanged:Fire({ UserInputType = "Move", Delta = { X = 0, Y = 0, Z = 0 }, Position = at() }, processed == true)
	end
	function f:End(processed) input.InputEnded:Fire({ UserInputType = "LMB", Position = at() }, processed == true) end
	f:Flush(); return f
end

local f = fixture()
check(f.Camera.CameraSubject == f.Humanoid, "initial subject attaches")
check(f.Steps.HHC_LeftMouseCamera.Priority == 199, "rotation precedes default-camera collision step")
f:Begin(); f:End(); check(f.Clicks == 1, "short world click fires once")
f:Begin(); f:Move(2, 1); f:End(); check(f.Clicks == 2, "small mouse jitter is still a click")
f:Begin(); f:Move(6, 0); f:End(); check(f.Clicks == 2, "threshold drag never attacks")
f:Begin(); f:Move(3, 0); f:Move(-3, 0); f:End(); check(f.Clicks == 2, "drag back to origin never becomes a click")
f:Begin(nil, true); f:Move(20, 0); f:End(); check(f.Clicks == 2, "GUI input never starts world gesture")
for _, name in { "FactionPicker", "ClassPicker", "Panels", "WorldMap" } do
	f.Registry[name].Open = true; f:Begin(); f:End(); check(f.Clicks == 2, name .. " blocks primary gesture")
	f.Registry[name].Open = false
end
f:Begin(); f.Registry.Panels.Open = true; f:End(); check(f.Clicks == 2, "opening a panel mid-click cancels attack")
f.Registry.Panels.Open = false
f:Begin(); f:Move(1, 0, true); f:End(); check(f.Clicks == 2, "moving over processed GUI cancels")
f:Begin(); f.Input.WindowFocusReleased:Fire(); f:End(); check(f.Clicks == 2, "window blur cancels")
f:Begin(); f.Gui.MenuOpened:Fire(); f:End(); check(f.Clicks == 2, "Roblox menu cancels")
f.Input.RightDown = true; f:Begin(); f:End(); check(f.Clicks == 2, "RMB has priority")
f.Input.RightDown = false; f:Begin(); f:Begin("RMB"); f:End(); check(f.Clicks == 2, "RMB during left gesture cancels it")
f:Begin("Touch"); f:End(); check(f.Clicks == 2, "touch is left to Roblox")
f.Input.TextBox = {}; f:Begin(); f:End(); check(f.Clicks == 2, "text focus blocks click")
f.Input.TextBox = nil
f.Player.Ready = false; f:Begin(); f:End(); check(f.Clicks == 2, "loading blocks click")
f.Player.Ready = true
f.Camera.CameraType = "Scriptable"; f:Begin(); f:End(); check(f.Clicks == 2, "scripted view blocks click")
f.Camera.Signals.CameraType:Fire(); f:Flush(); check(f.Camera.CameraType == "Scriptable", "scripted camera mode preserved")
f.Camera.CameraType = "Custom"
f:Begin(); local old = f.Player.Character
f.Player.CharacterRemoving:Fire(old); f:End(); check(f.Clicks == 2, "respawn cancels held gesture")
local replacement = f.NewCharacter(false, nil); f.Player.Character = replacement; f.Player.CharacterAdded:Fire(replacement)
f:Flush(); check(f.Camera.CameraSubject == f.Humanoid, "wait for parent and humanoid")
replacement.Parented = true; replacement.AncestryChanged:Fire(); f:Flush()
check(f.Camera.CameraSubject == f.Humanoid, "no nil subject assigned during replication")
local nextHumanoid = { IsA = f.Humanoid.IsA }; replacement.Humanoid = nextHumanoid; replacement.ChildAdded:Fire(nextHumanoid); f:Flush()
check(f.Camera.CameraSubject == nextHumanoid, "late replicated humanoid becomes subject")
check(f.Camera.CFrame == "unchanged", "lifecycle and gestures alone do not replace camera transform")
local g=fixture(); g.Camera.CFrame=CF.new(vec(3,8,12))
g:Begin(); g:Move(100,0); g.Steps.HHC_LeftMouseCamera.Fn()
check(math.abs(g.Camera.CFrame.LookVector.X-math.sin(.3))<1e-8,"100px right drag rotates view right by .3rad")
check(g.Camera.CFrame.Position.X==3 and g.Camera.CFrame.Position.Y==8 and g.Camera.CFrame.Position.Z==12,"rotation seed preserves camera position for Roblox follow/occlusion")
g:End(); local after=g.Camera.CFrame; g.Steps.HHC_LeftMouseCamera.Fn()
check(g.Camera.CFrame==after and g.Clicks==0,"released rendered drag does not repeat rotation or attack")
g:Begin(); g:Move(0,-10000); g:End(); g.Steps.HHC_LeftMouseCamera.Fn()
check(math.abs(math.asin(g.Camera.CFrame.LookVector.Y)-math.rad(80))<1e-8,"up pitch clamps at 80 degrees even after release")
g:Begin(); g:Move(0,10000); g.Steps.HHC_LeftMouseCamera.Fn()
check(math.abs(math.asin(g.Camera.CFrame.LookVector.Y)+math.rad(80))<1e-8,"down pitch clamps at -80 degrees")
g.Registry.Panels.Open=true; g:Move(10,10); after=g.Camera.CFrame; g.Steps.HHC_LeftMouseCamera.Fn()
check(g.Camera.CFrame==after,"panel appearing mid-drag cancels pending camera movement")
-- Cursor Position (not Delta) drives rotation: a zero-Delta move of 100px still turns the view.
do
	local h=fixture(); h.Camera.CFrame=CF.new(vec(0,5,10))
	h:Begin(); h:Move(100,0); h.Steps.HHC_LeftMouseCamera.Fn()
	check(math.abs(h.Camera.CFrame.LookVector.X-math.sin(.3))<1e-8,"zero-Delta cursor move did not rotate via Position difference")
	h:End(); check(h.Clicks==0,"Position-measured drag fired a click")
	-- Repeated moves accumulate from the last cursor sample, not from the press origin.
	h.Camera.CFrame=CF.new(vec(0,5,10))
	h:Begin(); h:Move(50,0); h:Move(50,0); h.Steps.HHC_LeftMouseCamera.Fn(); h:End()
	check(math.abs(h.Camera.CFrame.LookVector.X-math.sin(.3))<1e-8,"two 50px samples did not sum to one 100px turn")
end
-- Shift lock / first person (MouseBehavior ~= Default) leaves turning to Roblox; no jump when unlocking mid-drag.
for _, behavior in { "LockCenter", "LockCurrentPosition" } do
	local h=fixture(); h.Camera.CFrame=CF.new(vec(0,5,10))
	h.Input.MouseBehavior=behavior
	h:Begin(); h:Move(200,0); h:Move(200,40); local before=h.Camera.CFrame; h.Steps.HHC_LeftMouseCamera.Fn()
	check(h.Camera.CFrame==before, behavior.." locked cursor drag rotated the camera")
	h.Input.MouseBehavior="Default"
	h:Move(0,0); h.Steps.HHC_LeftMouseCamera.Fn()
	check(h.Camera.CFrame==before, behavior.." unlock mid-hold jumped by the locked-cursor distance")
	h:Move(10,0); h:Move(10,0); h.Steps.HHC_LeftMouseCamera.Fn()
	check(math.abs(h.Camera.CFrame.LookVector.X-math.sin(.06))<1e-8,
		behavior.." first default-cursor samples after unlock did not rotate from the new origin")
	h:End(); check(h.Clicks==0, behavior.." drag after unlock fired a click")
end
print("CAMERA_INPUT_SUMMARY checks=" .. checks .. " failed=0")
