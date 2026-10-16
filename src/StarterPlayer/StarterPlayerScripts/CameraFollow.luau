-- Keep Roblox's default camera attached when the server replaces an avatar with a costume rig.
-- A23-51 (user 2026-10-06): the camera turns with the RIGHT mouse drag only, owned by Roblox's default PlayerModule
-- camera (nothing here touches it); a left drag never turns the camera. A left press on the world = one attack:
-- PrimaryClick fires on the press, holding or dragging never repeats it. Touch and gamepad stay with Roblox.
-- A23-91 (user 2026-10-09 "캐릭터 따라서 카메라 회전하는 거 있어야겠다 … 전에는 좀 어색해가지고 없애달라고 한 거거든?
-- 완벽하게 해줘, 콘솔 게임처럼!"): the console-style follow, the default again (Settings "Cam" = "Follow"; "Free" = off).
-- Why the A23-65 / A23-74 follow felt awkward (and was turned off on 10/08): (a) it moved when I did NOT - 0.25 s after
-- a stop the camera swung round behind me at up to 120 deg/s (the "recenter"); (b) its turn speed jumped from 0 to full
-- and back with no ease, so every start / stop jerked; (c) a 6 deg dead zone turned it for every small steer; (d) a held
-- side key chased its own camera-relative direction and kept circling; (e) after a swing it froze 0.5 s, then snapped
-- on again; (f) its ease (share of the angle per frame) changed with the frame rate.
-- Now one yaw-only spring around the camera Focus, after Roblox's camera each frame (FOLLOW.Spring, numbers in
-- Config.CameraFollow, copied over FOLLOW at Start):
--   1 only while I walk: standing still never turns it (the old recenter is gone); a stop brakes the turn quickly;
--   2 a target turn speed = Gain x (the angle beyond DeadZone, 15 deg - smaller misalignments are left alone), the
--     turn speed follows it like a spring (Response, exp(-k dt): the same at 30 and 60 fps) and changes by at most
--     MaxAccel per second - no jerks;
--   3 walking toward the camera (walk . look < BackDot) never turns it; a sideways walk turns it at SideMin of the speed,
--     a forward walk at full;
--   4 a hand turn (right drag, a finger drag on the camera side, the right stick, Roblox's keyboard / trackpad turn)
--     stops it for ManualHold s, then it builds up again from 0;
--   5 for CombatHold s after my swing / skill it turns at CombatScale only (the target stays on screen);
--   6 the pitch is never touched (only a yaw around the Focus); walls: Roblox's own camera occlusion;
--   7 PC, phone (the left stick is camera-relative like the keys) and gamepad the same; a hitch counts as MaxDt;
--   8 motion sickness: never above MaxRate, never a circle tighter than MinRadius studs; 'Screen shake' off / Roblox's
--     Reduced Motion = SlowMaxRate.
-- Phone: Roblox's own Follow touch camera would turn too (DevTouchCameraMovementMode UserChoice), so Start sets my touch
-- camera to Classic (FOLLOW.TouchClassic); if Roblox's Follow camera is still active (a PC player who picked it, or the
-- set failed) this turn stays off (FOLLOW.RobloxFollows): never two turns at once. Shift lock / first person / windows:
-- off.
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
	-- A23-91 numbers; Config.CameraFollow (the table the user's feedback changes) overrides them at Start
	DeadZone = math.rad(15), -- a smaller angle between my walk and the camera look is left alone
	Gain = 2.2, -- target turn speed (rad / s) per rad of angle beyond DeadZone
	SideMin = 0.35, -- a sideways walk turns at this share of the speed (forward = 1, smooth in between)
	BackDot = -0.3, -- walk . camera look below this (walking toward the camera) = no turn
	Response = 6, -- 1 / s: how fast the turn speed follows its target (spring, frame-rate free)
	StopResponse = 14, -- 1 / s: the same after I stop walking (brakes quickly)
	MaxAccel = math.rad(240), -- rad / s per s: the most the turn speed changes in a second
	MaxRate = math.rad(90), SlowMaxRate = math.rad(50), -- rad / s cap ('Screen shake' off / Reduced Motion = slow)
	MinRadius = 45, -- studs: the cap is never above my speed / MinRadius (no tight circles)
	MinMove = 0.2, -- MoveDirection length that counts as walking
	ManualHold = 1.5, -- s after a hand turn: no follow (then it builds up from 0)
	CombatHold = 1.5, CombatScale = 0.3, -- s after my swing / skill: the turn at this share
	MaxDt = 1 / 20, -- s: a longer frame (a hitch) counts as this long
	CameraSide = 0.4, -- a finger drag that starts right of this share of the screen turns the camera (not the stick)
	-- Roblox's own keyboard camera turn (Config.Keybinds Reserved): held or pressed = a hand turn (A23-74 review)
	TurnKeys = { Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Comma, Enum.KeyCode.Period },
	LastManual = -math.huge, LastAttack = -math.huge, Touches = {},
	Vel = 0, -- the current turn speed (rad / s, + = left)
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

-- A23-91: this frame's yaw (rad, + = left) around the camera Focus, or nil; updates FOLLOW.Vel. Pure apart from FOLLOW
-- (the offline test drives it): cx, cz = the camera look (flat, unit); mx, mz, ml = my MoveDirection (flat) and its
-- length; speed = my WalkSpeed; slow = 'Screen shake' off / Reduced Motion
function FOLLOW.Spring(cx, cz, mx, mz, ml, speed, dt, now, slow)
	dt = math.clamp(dt, 0, FOLLOW.MaxDt)
	if now - FOLLOW.LastManual < FOLLOW.ManualHold then
		FOLLOW.Vel = 0 -- a hand turn: my own view; afterwards it builds up again from 0
		return nil
	end
	local target, limit = 0, math.huge
	local walking = ml >= FOLLOW.MinMove
	if walking then
		local ux, uz = mx / ml, mz / ml
		local dot = cx * ux + cz * uz
		local angle = math.atan2(cz * ux - cx * uz, dot) -- signed yaw from the camera look to my walk
		local excess = math.abs(angle) - FOLLOW.DeadZone
		if dot >= FOLLOW.BackDot then limit = math.max(0, excess) end -- never past the dead zone's edge (no overshoot)
		if dot >= FOLLOW.BackDot and excess > 0 then
			local forward = math.clamp(dot, 0, 1)
			local share = FOLLOW.SideMin + (1 - FOLLOW.SideMin) * forward
			local cap = math.min(slow and FOLLOW.SlowMaxRate or FOLLOW.MaxRate,
				(tonumber(speed) or 0) * math.min(1, ml) / FOLLOW.MinRadius)
			if now - FOLLOW.LastAttack < FOLLOW.CombatHold then share *= FOLLOW.CombatScale end
			local sign = angle > 0 and 1 or -1
			target = sign * math.min(FOLLOW.Gain * excess, cap) * share
		end
	end
	local k = walking and FOLLOW.Response or FOLLOW.StopResponse
	local want = FOLLOW.Vel + (target - FOLLOW.Vel) * (1 - math.exp(-k * dt))
	local step = FOLLOW.MaxAccel * dt
	FOLLOW.Vel = math.clamp(want, FOLLOW.Vel - step, FOLLOW.Vel + step)
	if not walking and math.abs(FOLLOW.Vel) < math.rad(0.5) then FOLLOW.Vel = 0 end
	local yaw = FOLLOW.Vel * dt
	if math.abs(yaw) > limit then
		yaw = (yaw > 0 and 1 or -1) * limit
		FOLLOW.Vel = dt > 0 and yaw / dt or 0 -- reached the edge: the speed stops with it (no coasting past)
	end
	if math.abs(yaw) < 1e-6 then return nil end
	return yaw
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
-- is Follow on touch and Classic on a PC). the follow (FOLLOW.Spring) stays off then so two turns never add up (A23-74 review)
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
-- mode and Roblox's CameraModule switches on the change, so phones get Classic and the walking turn is FOLLOW.Spring's
-- alone. pcall: if the set fails, RobloxFollows() keeps the follow off instead. Returns whether the mode is Classic now
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
	local now = os.clock()
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or FOLLOW.KeyTurn() then
		FOLLOW.LastManual = now
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local move = humanoid and humanoid.MoveDirection
	if not move then return end
	if setting("Cam", "Follow") == "Free" or blocked() or FOLLOW.RobloxFollows()
		or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then -- shift lock turns me itself
		FOLLOW.Vel = 0
		return
	end
	local camera = workspace.CurrentCamera
	local cf, focus = camera.CFrame, camera.Focus.Position
	if (focus - cf.Position).Magnitude < 1 then FOLLOW.Vel = 0 return end -- first person
	local look = cf.LookVector
	local cx, cz = look.X, look.Z
	local cl = math.sqrt(cx * cx + cz * cz)
	if cl < 0.05 then return end
	cx, cz = cx / cl, cz / cl
	local mx, mz = move.X, move.Z
	local ml = math.sqrt(mx * mx + mz * mz)
	local slow = setting("Shake", true) == false or FOLLOW.Reduced()
	local a = FOLLOW.Spring(cx, cz, mx, mz, ml, humanoid.WalkSpeed, dt, now, slow)
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

-- my own swing / skill (the server's Fx, manual and auto): the follow turns at CombatScale for CombatHold s
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

-- 게임 플레이 3판 ① (최종 검수 10/16: the Halo first screen faced the guide but the camera looked at the stairs): once per
-- character, when Roblox's camera has it (a spawn, a respawn, the opening handing the camera back), the camera turns
-- round behind it at its current zoom - the server faces a new character toward the guide / Fizzby, so that is on screen
function FOLLOW.SnapBehind(char)
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom or char ~= LocalPlayer.Character then return end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then return end
	look = look.Unit
	local dist = math.clamp((camera.CFrame.Position - camera.Focus.Position).Magnitude, 8, 16)
	local at = root.Position + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(at - look * dist + Vector3.new(0, dist * 0.35, 0), at)
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
	if humanoid and FOLLOW.SnappedFor ~= character then
		FOLLOW.SnappedFor = character
		pcall(function() task.delay(0.15, function() pcall(FOLLOW.SnapBehind, character) end) end)
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
		-- A23-91: the numbers the user's feedback changes live in Config.CameraFollow (same names as FOLLOW)
		local okCfg, Config = pcall(function() return require(shared:WaitForChild("Config")) end)
		if okCfg and type(Config) == "table" and type(Config.CameraFollow) == "table" then
			for key, value in Config.CameraFollow do
				if type(value) == "number" and type(FOLLOW[key]) == "number" then FOLLOW[key] = value end
			end
		end
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
