-- Keep Roblox's default camera attached when the server replaces an avatar with a costume rig.
-- A23-51 (user 2026-10-06): the camera turns with the RIGHT mouse drag only, owned by Roblox's default PlayerModule
-- camera (nothing here touches it); a left drag never turns the camera. A left press on the world = one attack:
-- PrimaryClick fires on the press, holding or dragging never repeats it. Touch and gamepad stay with Roblox.
-- A23-65 (user 2026-10-07 "캐릭터가 움직일 때 카메라도 같이 움직이면 좋겠어. 캐릭터의 뒤를 따라서!") and A23-74 (user
-- 2026-10-07 "카메라가 자동으로 뒤에 있어야 하는데 왜 안 돌아 / 카메라도 뒤통수 따라가랬잖아"): the camera ends up behind
-- my head. Both parts are yaw-only turns of the camera around its Focus, after Roblox's camera each frame (render step
-- HHC_CameraFollow), so Roblox's right drag (A23-51) still turns it freely:
-- 1. Walking (FOLLOW.WalkTurn): it turns toward my walking direction, which is the way my body faces (Humanoid
--    AutoRotate). The keys and the stick are camera-relative: turning the camera turns MoveDirection by the same amount,
--    so a held A / D / W+D never lines up and the turn never ends (a side view all the way; 검수 2026-10-07). The cap
--    (FOLLOW.Cap) therefore depends on the angle: the full 45 deg/s only within FullAngle (20 deg) of the camera look,
--    a smooth front-loaded fade to SideRate (16 deg/s) by SideAngle (60 deg), kept up to the backpedal limit. The
--    radius of that arc = walk speed / cap: at WalkSpeed 20, D = 72 studs, W+D = 70, a stick 37 deg off = 58 (f3ab1f1's
--    45 deg/s up to 60 deg made 25-stud circles). On top, the cap is never above my speed / MinRadius (55 studs; review
--    A23-74 (user 2026-10-07): a stick 18-34 deg off made 35-48-stud circles), so no held input circles tighter, a
--    half-pushed stick or a slower walk included. A backpedal toward the camera (walk . look < BackDot) never turns.
-- 2. Standing (FOLLOW.CenterTurn): once the walk has ended for StopDelay s, it eases round behind my facing
--    (HumanoidRootPart LookVector): speeding up at CenterAccel to CenterRate (120 deg/s), slowing in on the angle, a
--    90 deg side view is behind me within ~1 s; DeadZone keeps it still once behind (a running recenter settles to
--    Settle). This is what puts the camera behind the head after A / D / W+D. Not when my body faces the camera (a
--    backpedal ended: no 180 deg spin, the A23-74 exception), and a hand turn within ManualHold before the stop or any
--    time after it is my own view: kept until the next walk.
-- Neither turns for FOLLOW.ManualHold s after a hand turn (right drag, a finger drag on the camera side, the right
-- stick, and Roblox's own keyboard / trackpad camera turn: Left / Right arrows, Comma / Period, a two-finger trackpad
-- pan - review A23-74 (user 2026-10-07): a held Right arrow turned 14 deg and snapped back), for FOLLOW.AttackHold s
-- after my swing / skill (FaceTarget / the server turning my body never whips the camera; the recenter resumes after
-- it), in shift lock or first person, and whenever blocked() (windows, the opening, menus, loading). Settings "Cam" =
-- "Free" turns both off; 'Screen shake' off or Roblox's Reduced Motion = slower rates. A frame longer than MaxDt (a
-- hitch) turns as if it were MaxDt long.
-- Phone: the left thumbstick walks (a camera-relative MoveDirection like the keys) and so drives the follow; its touch
-- never counts as a hand turn. Roblox's touch camera would be its Follow mode (StarterPlayer DevTouchCameraMovementMode
-- = UserChoice, the phone default), which also turns on sideways walks (a 90 deg stick: 10-stud circles), so Start sets
-- my DevTouchCameraMode to Classic (FOLLOW.TouchClassic); if Roblox's Follow camera is still active on this device (a
-- PC player who picked Follow, or the set failed) WalkTurn stays off (FOLLOW.RobloxFollows): never two turns at once.
-- History: A23-65 ran only for walk . camera look >= 0.5 (69f1fe45), so single side keys never turned; f3ab1f1 turned
-- on side walks but never ended behind the head.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local CameraFollow = {}
local primaryClick = Instance.new("BindableEvent")
CameraFollow.PrimaryClick = primaryClick.Event
local registry = nil
local started, queued = false, false
local character = nil
local characterConnections, cameraConnections = {}, {}
local FOLLOW = {
	-- walking: the turn cap (rad / s) within FullAngle of the camera look; 'Screen shake' off / Reduced Motion = slow.
	-- Studio 2026-10-07: at 110 deg/s a held side key chased its own camera-relative direction into an 8-stud circle
	Rate = math.rad(45), SlowRate = math.rad(25),
	-- A23-74: the cap from SideAngle off the camera look on (diagonals, sideways). Arc radius = walk speed / cap:
	-- 20 studs/s at 16 deg/s = 72 studs (45 deg/s = 25 studs, which 검수 saw as circling)
	SideRate = math.rad(16), SlowSideRate = math.rad(10),
	FullAngle = math.rad(20), SideAngle = math.rad(60), -- the fade window (FOLLOW.Cap)
	Fade = 6, -- fade shape (1 - t)^Fade * (1 + Fade * t): flat at both ends, mostly gone by t = 0.4 (a 37 deg stick)
	-- A23-74 (user 2026-10-07) review: the cap is never above my speed / MinRadius (rad / s), so a held input never
	-- circles tighter than this (studs; >= ~50 asked): 20 studs/s -> 20.8 deg/s (the 45 deg/s cap made 38 studs at 25 deg)
	MinRadius = 55,
	MaxDt = 1 / 20, -- s: a longer frame (a hitch) turns as if it were this long (a 0.5 s hitch jumped the recenter 60 deg)
	BackDot = -0.35, -- walk / facing . camera look below this (more than ~110 deg off) = backing up: never turn
	Ease = 1.2, SlowEase = 0.7, -- share of the remaining angle turned per second
	DeadZone = math.rad(6), -- a smaller misalignment is left alone (walking, and before a recenter starts)
	MinMove = 0.2, -- MoveDirection length that counts as walking
	-- standing: the A23-74 recenter behind my facing
	StopDelay = 0.25, -- s standing before it starts
	CenterRate = math.rad(120), SlowCenterRate = math.rad(60), -- top speed (rad / s)
	CenterAccel = math.rad(800), SlowCenterAccel = math.rad(400), -- ease in (rad / s per s)
	CenterEase = 8, SlowCenterEase = 4, -- ease out: share of the remaining angle per second
	Settle = math.rad(1), -- a running recenter stops here
	ManualHold = 1.5, AttackHold = 0.5, -- s
	CameraSide = 0.4, -- a finger drag that starts right of this share of the screen turns the camera (not the stick)
	-- Roblox's own keyboard camera turn (Config.Keybinds Reserved): held or pressed = a hand turn (A23-74 review)
	TurnKeys = { Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Comma, Enum.KeyCode.Period },
	LastManual = -math.huge, LastAttack = -math.huge, Touches = {},
	StopAt = math.huge, -- os.clock() when the last walk ended (math.huge while walking)
	Centering = false, CenterSpeed = 0, -- a recenter is running / its current speed (rad / s)
}

local function blocked()
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return true end
	if LocalPlayer:GetAttribute("DataLoaded") ~= true then return true end
	for _, name in { "FactionPicker", "ClassPicker", "Panels", "WorldMap" } do
		local module = registry and registry[name]
		if module and type(module.IsOpen) == "function" and module.IsOpen() then return true end
	end
	local camera = workspace.CurrentCamera
	return not camera or camera.CameraType ~= Enum.CameraType.Custom
		or not character or character ~= LocalPlayer.Character
		or not character:IsDescendantOf(workspace)
end

-- one attack per left press on the world (a press on a GUI is processed and never attacks)
local function onPrimaryBegan(input, processed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or processed or blocked() then return end
	primaryClick:Fire()
end

-- the settings value (C.Settings), default when unknown
local function setting(key, default)
	local st = registry and registry.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return default end
	local ok, v = pcall(st.Get, key)
	if not ok or v == nil then return default end
	return v
end

-- Roblox's Reduced Motion (Fx MOTION.ShakeAllowed reads it too); pcall: an older client may lack the property
function FOLLOW.Reduced()
	local ok, reduced = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and reduced == true
end

-- the walking turn cap (rad / s) for a walk `off` rad away from the camera look (A23-74): `full` within FullAngle, a
-- smooth fade (flat at both ends) to `side` at SideAngle and beyond. Front-loaded so diagonals already make wide arcs
function FOLLOW.Cap(off, full, side)
	local t = math.clamp((off - FOLLOW.FullAngle) / (FOLLOW.SideAngle - FOLLOW.FullAngle), 0, 1)
	return side + (full - side) * (1 - t) ^ FOLLOW.Fade * (1 + FOLLOW.Fade * t)
end

-- walking: this frame's yaw (rad, + = left) toward my walking direction (= my back: AutoRotate), or nil.
-- speed = my Humanoid WalkSpeed (studs / s)
function FOLLOW.WalkTurn(cx, cz, move, dt, slow, speed)
	local mx, mz = move.X, move.Z
	local ml = math.sqrt(mx * mx + mz * mz)
	if ml < 0.05 then return nil end
	mx, mz = mx / ml, mz / ml
	local dot = cx * mx + cz * mz
	if dot < FOLLOW.BackDot then return nil end -- backing up toward the camera: never spin (the A23-74 exception)
	-- signed yaw (about +Y) from the camera heading to the walking heading
	local angle = math.atan2(cz * mx - cx * mz, dot)
	if math.abs(angle) < FOLLOW.DeadZone then return nil end
	-- A23-74 review: the arc radius = my actual speed (a half-pushed stick walks slower) / the rate >= MinRadius
	local rate = math.min(FOLLOW.Cap(math.abs(angle), slow and FOLLOW.SlowRate or FOLLOW.Rate,
		slow and FOLLOW.SlowSideRate or FOLLOW.SideRate), (tonumber(speed) or 0) * math.min(1, ml) / FOLLOW.MinRadius)
	local ease = slow and FOLLOW.SlowEase or FOLLOW.Ease
	return math.clamp(angle * math.min(1, ease * dt), -rate * dt, rate * dt)
end

-- standing: this frame's yaw (rad) bringing the camera round behind my facing (the A23-74 recenter), or nil.
-- was = a recenter ran last frame
function FOLLOW.CenterTurn(cx, cz, humanoid, now, dt, slow, was)
	-- StopDelay s after the walk ends; a hand turn within ManualHold before the stop or any time after it = my own view
	if now - FOLLOW.StopAt < FOLLOW.StopDelay
		or FOLLOW.LastManual >= FOLLOW.StopAt - FOLLOW.ManualHold then return nil end
	local root = humanoid.RootPart
	if not root or humanoid.Health <= 0 then return nil end
	local face = root.CFrame.LookVector
	local fx, fz = face.X, face.Z
	local fl = math.sqrt(fx * fx + fz * fz)
	if fl < 0.3 then return nil end -- lying down / tumbling: no clear facing
	fx, fz = fx / fl, fz / fl
	local dot = cx * fx + cz * fz
	if dot < FOLLOW.BackDot then return nil end -- I face the camera (a backpedal ended): no 180 deg spin
	local angle = math.atan2(cz * fx - cx * fz, dot)
	-- DeadZone keeps it still once behind; a running recenter goes on until Settle
	if math.abs(angle) < (was and FOLLOW.Settle or FOLLOW.DeadZone) then return nil end
	FOLLOW.Centering = true
	-- ease in: the speed builds up at CenterAccel to the top speed; ease out: CenterEase of the remaining angle per second
	FOLLOW.CenterSpeed = math.min(slow and FOLLOW.SlowCenterRate or FOLLOW.CenterRate,
		(was and FOLLOW.CenterSpeed or 0) + (slow and FOLLOW.SlowCenterAccel or FOLLOW.CenterAccel) * dt)
	local ease = slow and FOLLOW.SlowCenterEase or FOLLOW.CenterEase
	return math.clamp(angle * math.min(1, ease * dt), -FOLLOW.CenterSpeed * dt, FOLLOW.CenterSpeed * dt)
end

-- Roblox's keyboard camera turn (TurnKeys) held right now, outside a text box: a hand turn (A23-74 review)
function FOLLOW.KeyTurn()
	if UserInputService:GetFocusedTextBox() then return false end -- typing a comma in chat turns nothing
	for _, key in FOLLOW.TurnKeys do
		if UserInputService:IsKeyDown(key) then return true end
	end
	return false
end

-- Roblox's own Follow camera is active on this device (it turns on sideways walks itself; Roblox's CameraModule rule:
-- touch reads DevTouchCameraMode, a PC DevComputerCameraMode; UserChoice = the player's Roblox setting, whose Default
-- is Follow on touch and Classic on a PC). WalkTurn stays off then so two turns never add up (A23-74 review)
function FOLLOW.RobloxFollows()
	local ok, follows = pcall(function()
		local touch = UserInputService.TouchEnabled
		local mode = (if touch then LocalPlayer.DevTouchCameraMode else LocalPlayer.DevComputerCameraMode).Name
		if mode == "UserChoice" then
			FOLLOW.UserGameSettings = FOLLOW.UserGameSettings or UserSettings():GetService("UserGameSettings")
			local user = FOLLOW.UserGameSettings
			mode = (if touch then user.TouchCameraMovementMode else user.ComputerCameraMovementMode).Name
			if mode == "Default" then mode = if touch then "Follow" else "Classic" end
		end
		return mode == "Follow"
	end)
	return ok and follows == true
end

-- A23-74 review: StarterPlayer.DevTouchCameraMovementMode is UserChoice, so a phone gets Roblox's Follow camera (it
-- turns on a sideways walk too: a 90 deg stick made 10-stud circles). A LocalScript may set its own player's camera
-- mode and Roblox's CameraModule switches on the change, so phones get Classic and the walking turn is WalkTurn's
-- alone. pcall: if the set fails, RobloxFollows() keeps WalkTurn off instead. Returns whether the mode is Classic now
function FOLLOW.TouchClassic()
	local ok, classic = pcall(function()
		local modes = Enum.DevTouchCameraMovementMode
		local mode = LocalPlayer.DevTouchCameraMode
		if mode == modes.UserChoice or mode == modes.Follow then LocalPlayer.DevTouchCameraMode = modes.Classic end
		return LocalPlayer.DevTouchCameraMode == modes.Classic
	end)
	return ok and classic == true
end

-- one frame of the follow turn (after Roblox's camera, priority Camera + 1)
function FOLLOW.Step(dt)
	dt = math.min(dt, FOLLOW.MaxDt) -- A23-74 review: a hitch never jumps the camera
	local now = os.clock()
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or FOLLOW.KeyTurn() then
		FOLLOW.LastManual = now
	end
	local was = FOLLOW.Centering
	FOLLOW.Centering = false -- set again only by a frame that recenters
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local move = humanoid and humanoid.MoveDirection
	if not move then return end
	-- walk / stop bookkeeping before every other check, so a walk that ends behind a window still counts
	local walking = move.Magnitude >= FOLLOW.MinMove
	if walking then
		FOLLOW.StopAt = math.huge
	elseif FOLLOW.StopAt == math.huge then
		FOLLOW.StopAt = now
	end
	if setting("Cam", "Follow") == "Free" or blocked() then return end
	if now - FOLLOW.LastManual < FOLLOW.ManualHold or now - FOLLOW.LastAttack < FOLLOW.AttackHold then return end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return end -- shift lock turns me itself
	local camera = workspace.CurrentCamera
	local cf, focus = camera.CFrame, camera.Focus.Position
	if (focus - cf.Position).Magnitude < 1 then return end -- first person
	local look = cf.LookVector
	local cx, cz = look.X, look.Z
	local cl = math.sqrt(cx * cx + cz * cz)
	if cl < 0.05 then return end
	cx, cz = cx / cl, cz / cl
	local slow = setting("Shake", true) == false
		or FOLLOW.Reduced()
	local a = nil
	if not walking then
		a = FOLLOW.CenterTurn(cx, cz, humanoid, now, dt, slow, was)
	elseif not FOLLOW.RobloxFollows() then -- Roblox's Follow camera turns on the walk itself
		a = FOLLOW.WalkTurn(cx, cz, move, dt, slow, humanoid.WalkSpeed)
	end
	if not a then return end
	local c, sn = math.cos(a), math.sin(a)
	local function yaw(v) return Vector3.new(v.X * c + v.Z * sn, v.Y, -v.X * sn + v.Z * c) end
	local pos = focus + yaw(cf.Position - focus)
	camera.CFrame = CFrame.lookAt(pos, pos + yaw(look))
end

-- a hand turn: mouse movement with the right button down, a finger drag on the camera side, the right stick (Roblox's
-- keyboard turn: FOLLOW.KeyTurn every frame and OnInputBegan; a trackpad pan: OnPointerAction)
function FOLLOW.OnInputChanged(input, processed)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseMovement then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then FOLLOW.LastManual = os.clock() end
	elseif kind == Enum.UserInputType.Touch then
		if not processed and FOLLOW.Touches[input] then FOLLOW.LastManual = os.clock() end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.25 then
		FOLLOW.LastManual = os.clock()
	end
end

-- touches that start on the camera side (right of CameraSide) and not on a GUI can turn the camera. A TurnKeys press is
-- a hand turn at once (a quick Comma / Period tap can begin and end between two frames; Roblox's camera binds these
-- keys itself, so `processed` is not trusted here - a focused text box is)
function FOLLOW.OnInputBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if table.find(FOLLOW.TurnKeys, input.KeyCode) and not UserInputService:GetFocusedTextBox() then
			FOLLOW.LastManual = os.clock()
		end
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Touch or processed then return end
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	local width = size and size.X or 0
	if width > 0 and input.Position.X > width * FOLLOW.CameraSide then FOLLOW.Touches[input] = true end
end

function FOLLOW.OnInputEnded(input)
	FOLLOW.Touches[input] = nil
end

-- a two-finger trackpad pan turns Roblox's camera: a hand turn (A23-74 review). Counted even when processed: a missed
-- turn would fight the player's view, a counted one only waits ManualHold
function FOLLOW.OnPointerAction(_wheel, pan)
	if pan and pan.Magnitude > 1e-3 then FOLLOW.LastManual = os.clock() end
end

-- my own swing / skill (the server's Fx, manual and auto): hold the follow for AttackHold s
function FOLLOW.OnFx(kind, data)
	if (kind == "Swing" or kind == "Release" or kind == "Skill") and type(data) == "table"
		and data.UserId == LocalPlayer.UserId then
		FOLLOW.LastAttack = os.clock()
	end
end

local function disconnect(connections)
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function updateSubject()
	queued = false
	local camera = workspace.CurrentCamera
	-- Scriptable cutscenes and other explicit camera modes retain their own subject.
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then return end
	if not character or character ~= LocalPlayer.Character or not character:IsDescendantOf(workspace) then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

local function queueUpdate()
	if queued then return end
	queued = true
	task.defer(updateSubject)
end

local function bindCharacter(nextCharacter)
	disconnect(characterConnections)
	character = nextCharacter
	if character then
		-- CharacterAdded may arrive before parenting or the Humanoid replicates.
		table.insert(characterConnections, character.AncestryChanged:Connect(queueUpdate))
		for _, signal in { character.ChildAdded, character.ChildRemoved } do
			table.insert(characterConnections, signal:Connect(function(child)
				if child:IsA("Humanoid") then queueUpdate() end
			end))
		end
	end
	queueUpdate()
end

local function bindCamera()
	disconnect(cameraConnections)
	local camera = workspace.CurrentCamera
	if camera then
		for _, property in { "CameraSubject", "CameraType" } do
			table.insert(cameraConnections, camera:GetPropertyChangedSignal(property):Connect(queueUpdate))
		end
	end
	queueUpdate()
end

function CameraFollow.Init(nextRegistry)
	registry = nextRegistry
end

function CameraFollow.Start()
	if started then return end
	started = true
	UserInputService.InputBegan:Connect(onPrimaryBegan)
	-- A23-65 / A23-74: the follow turn and the recenter
	UserInputService.InputBegan:Connect(FOLLOW.OnInputBegan)
	UserInputService.InputChanged:Connect(FOLLOW.OnInputChanged)
	UserInputService.InputEnded:Connect(FOLLOW.OnInputEnded)
	pcall(function() UserInputService.PointerAction:Connect(FOLLOW.OnPointerAction) end) -- an older client may lack it
	FOLLOW.TouchClassic() -- phones: Roblox's Classic touch camera, the walking turn is ours (A23-74 review)
	RunService:BindToRenderStep("HHC_CameraFollow", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(FOLLOW.Step, dt)
		if not ok then warn("[CameraFollow] follow: " .. tostring(err)) end
	end)
	task.spawn(function()
		local shared = ReplicatedStorage:WaitForChild("Shared", 30)
		local okNet, Net = pcall(function() return require(shared:WaitForChild("Net")) end)
		if okNet and type(Net) == "table" then
			pcall(function() Net.Get("Fx").OnClientEvent:Connect(FOLLOW.OnFx) end)
		end
	end)
	LocalPlayer.CharacterAdded:Connect(bindCharacter)
	LocalPlayer.CharacterRemoving:Connect(function(removing)
		if character == removing then bindCharacter(nil) end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCharacter(LocalPlayer.Character)
	bindCamera()
end

CameraFollow.Follow = FOLLOW -- test aid (tools/test_camera_input.py follow group)

return CameraFollow
