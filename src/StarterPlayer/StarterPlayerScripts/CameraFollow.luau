-- Keep Roblox's default camera attached when the server replaces an avatar with a costume rig.
-- A23-51 (user 2026-10-06): the camera turns with the RIGHT mouse drag only, owned by Roblox's default PlayerModule
-- camera (nothing here touches it); a left drag never turns the camera. A left press on the world = one attack:
-- PrimaryClick fires on the press, holding or dragging never repeats it. Touch and gamepad stay with Roblox.
-- A23-65 (user 2026-10-07 "캐릭터가 움직일 때 카메라도 같이 움직이면 좋겠어. 캐릭터의 뒤를 따라서!"): while I walk, the
-- camera turns slowly around me toward my walking direction (I end up seen from behind). It is a yaw-only turn of the
-- camera around its Focus, after Roblox's camera each frame (render step HHC_CameraFollow), capped per second and
-- eased (45 deg/s), slower with 'Screen shake' off. It never turns while I stand, while I walk toward the camera (no spinning
-- when backing up), for FOLLOW.ManualHold s after a hand turn (right drag, a finger drag on the camera side, the right
-- stick), for FOLLOW.AttackHold s after my swing / skill (FaceTarget / the server turning my body never whips the
-- camera), in shift lock or first person, and whenever blocked() (windows, the opening, menus, loading). Settings
-- "Cam" = "Free" turns it off. The right-drag turn itself stays Roblox's (A23-51).
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
	-- max turn speed (rad / s); 'Screen shake' off = slow. Studio 2026-10-07: at 110 deg/s a held sideways key (the
	-- stick to one side) chased its own camera-relative direction into an 8-stud circle; 45 deg/s makes a wide arc
	Rate = math.rad(45), SlowRate = math.rad(25),
	Ease = 1.2, SlowEase = 0.7, -- share of the remaining angle turned per second
	DeadZone = math.rad(6), -- a smaller misalignment is left alone
	BackDot = -0.25, -- walking toward the camera (walk . camera look below this): never turn
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
	if dot < FOLLOW.BackDot then return end
	-- signed yaw (about +Y) from the camera heading to the walking heading
	local angle = math.atan2(cz * mx - cx * mz, dot)
	if math.abs(angle) < FOLLOW.DeadZone then return end
	local slow = setting("Shake", true) == false
	local rate, ease = slow and FOLLOW.SlowRate or FOLLOW.Rate, slow and FOLLOW.SlowEase or FOLLOW.Ease
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
