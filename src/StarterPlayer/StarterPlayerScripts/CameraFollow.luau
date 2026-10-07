-- Keep Roblox's default camera attached when the server replaces an avatar with a costume rig.
-- A23-51 (user 2026-10-06): the camera turns with the RIGHT mouse drag only, owned by Roblox's default PlayerModule
-- camera (nothing here touches it); a left drag never turns the camera. A left press on the world = one attack:
-- PrimaryClick fires on the press, holding or dragging never repeats it. Touch and gamepad stay with Roblox.
-- A23-65 (user 2026-10-07 "캐릭터가 움직일 때 카메라도 같이 움직이면 좋겠어. 캐릭터의 뒤를 따라서!") and A23-74 (user
-- 2026-10-07 "카메라도 뒤통수 따라가랬잖아"): while I walk, the camera turns around me toward my walking direction, which
-- is the way my body faces (Humanoid AutoRotate), so I end up seen from behind. Every walk counts - forward, sideways,
-- diagonal - except a backpedal toward the camera (walk . camera look < FOLLOW.BackDot: no spinning when backing up).
-- It is a yaw-only turn of the camera around its Focus, after Roblox's camera each frame (render step HHC_CameraFollow),
-- eased and capped per second: 45 deg/s walking forward, down to 20 deg/s walking sideways (the keys and the stick are
-- camera-relative, so a held side key keeps walking 90 deg off the camera and the turn never ends: the low cap makes
-- that a wide gentle arc, not a tight circle), slower with 'Screen shake' off or Roblox's Reduced Motion. It never turns
-- while I stand, for FOLLOW.ManualHold s after a hand turn (right drag, a finger drag on the camera side, the right
-- stick), for FOLLOW.AttackHold s after my swing / skill (FaceTarget / the server turning my body never whips the
-- camera), in shift lock or first person, and whenever blocked() (windows, the opening, menus, loading). Settings
-- "Cam" = "Free" turns it off. The right-drag turn itself stays Roblox's (A23-51). Phone: the left thumbstick walks
-- (a camera-relative MoveDirection like the keys) and so drives the follow; its touch never counts as a hand turn.
-- Why A23-74: the A23-65 version ran only for walk . camera look >= 0.5 (69f1fe45). W already walks along the camera
-- look (nothing to turn) and A / D / S are all below 0.5, so with single keys it never turned.
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
	-- max turn speed (rad / s) walking forward; 'Screen shake' off / Reduced Motion = slow. Studio 2026-10-07: at 110
	-- deg/s a held sideways key (the stick to one side) chased its own camera-relative direction into an 8-stud circle
	Rate = math.rad(45), SlowRate = math.rad(25),
	-- A23-74 (user 2026-10-07): the cap walking sideways. A held side key circles with radius = walk speed / cap:
	-- 20 studs/s at 20 deg/s = 57 studs (a wide gentle arc; 45 deg/s = 25 studs, which 검수 saw as circling)
	SideRate = math.rad(20), SlowSideRate = math.rad(12),
	FwdDot = 0.5, -- walk . camera look >= this = forward (within 60 deg): the full Rate; the cap eases to SideRate at 0
	BackDot = -0.35, -- walk . camera look below this (more than ~110 deg off) = backing up toward the camera: never turn
	Ease = 1.2, SlowEase = 0.7, -- share of the remaining angle turned per second
	DeadZone = math.rad(6), -- a smaller misalignment is left alone
	MinMove = 0.2, -- MoveDirection length that counts as walking
	ManualHold = 1.5, AttackHold = 0.5, -- s
	CameraSide = 0.4, -- a finger drag that starts right of this share of the screen turns the camera (not the stick)
	LastManual = -math.huge, LastAttack = -math.huge, Touches = {},
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

-- one frame of the follow turn (after Roblox's camera, priority Camera + 1)
function FOLLOW.Step(dt)
	if setting("Cam", "Follow") == "Free" or blocked() then return end
	local now = os.clock()
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then FOLLOW.LastManual = now end
	if now - FOLLOW.LastManual < FOLLOW.ManualHold or now - FOLLOW.LastAttack < FOLLOW.AttackHold then return end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return end -- shift lock turns me itself
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local move = humanoid and humanoid.MoveDirection
	if not move or move.Magnitude < FOLLOW.MinMove then return end
	local camera = workspace.CurrentCamera
	local cf, focus = camera.CFrame, camera.Focus.Position
	if (focus - cf.Position).Magnitude < 1 then return end -- first person
	local look = cf.LookVector
	local cx, cz, mx, mz = look.X, look.Z, move.X, move.Z
	local cl, ml = math.sqrt(cx * cx + cz * cz), math.sqrt(mx * mx + mz * mz)
	if cl < 0.05 or ml < 0.05 then return end
	cx, cz, mx, mz = cx / cl, cz / cl, mx / ml, mz / ml
	local dot = cx * mx + cz * mz
	if dot < FOLLOW.BackDot then return end -- backing up toward the camera: never spin (A23-74 keeps this one exception)
	-- signed yaw (about +Y) from the camera heading to the walking heading (= my back while walking: AutoRotate)
	local angle = math.atan2(cz * mx - cx * mz, dot)
	if math.abs(angle) < FOLLOW.DeadZone then return end
	local slow = setting("Shake", true) == false
		or FOLLOW.Reduced()
	local full, side = slow and FOLLOW.SlowRate or FOLLOW.Rate, slow and FOLLOW.SlowSideRate or FOLLOW.SideRate
	local ease = slow and FOLLOW.SlowEase or FOLLOW.Ease
	-- A23-74: the full cap walking forward, easing down to the side cap walking sideways (a wide arc, not a circle)
	local rate = side + (full - side) * math.clamp(dot / FOLLOW.FwdDot, 0, 1)
	local a = math.clamp(angle * math.min(1, ease * dt), -rate * dt, rate * dt)
	local c, sn = math.cos(a), math.sin(a)
	local function yaw(v) return Vector3.new(v.X * c + v.Z * sn, v.Y, -v.X * sn + v.Z * c) end
	local pos = focus + yaw(cf.Position - focus)
	camera.CFrame = CFrame.lookAt(pos, pos + yaw(look))
end

-- a hand turn: mouse movement with the right button down, a finger drag on the camera side, the right stick
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

-- touches that start on the camera side (right of CameraSide) and not on a GUI can turn the camera
function FOLLOW.OnInputBegan(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Touch or processed then return end
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	local width = size and size.X or 0
	if width > 0 and input.Position.X > width * FOLLOW.CameraSide then FOLLOW.Touches[input] = true end
end

function FOLLOW.OnInputEnded(input)
	FOLLOW.Touches[input] = nil
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
	-- A23-65: the follow turn
	UserInputService.InputBegan:Connect(FOLLOW.OnInputBegan)
	UserInputService.InputChanged:Connect(FOLLOW.OnInputChanged)
	UserInputService.InputEnded:Connect(FOLLOW.OnInputEnded)
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
