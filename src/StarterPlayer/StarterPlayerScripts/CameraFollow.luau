-- Keep Roblox's default camera attached when the server replaces an avatar with a costume rig.
-- Feed left-mouse drag direction into Roblox's camera before its follow/zoom/occlusion update.
-- Right-mouse, touch and gamepad input remain owned by the default PlayerModule camera.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local CameraFollow = {}
local primaryClick = Instance.new("BindableEvent")
CameraFollow.PrimaryClick = primaryClick.Event
local registry = nil
local started, queued = false, false
local character = nil
local characterConnections, cameraConnections = {}, {}
local drag = { Held = false, Moved = false, Distance = 0, X = 0, Y = 0, Last = nil }
local DRAG_THRESHOLD, RADIANS_PER_PIXEL, PITCH_LIMIT = 6, 0.003, math.rad(80)

local function cancelDrag()
	drag.Held, drag.Moved, drag.Distance, drag.X, drag.Y, drag.Last = false, false, 0, 0, 0, nil
end

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

local function onPrimaryBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		cancelDrag() -- simultaneous buttons belong to Roblox's standard right-mouse orbit
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		cancelDrag()
		if not processed and not blocked()
			and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			drag.Held = true
			drag.Last = Vector2.new(input.Position.X, input.Position.Y)
		end
	end
end

local function onPrimaryChanged(input, processed)
	if not drag.Held or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	if processed or blocked() then cancelDrag(); return end
	-- Shift lock / first person lock the cursor: Roblox's own camera already turns with the mouse there.
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then drag.Last = nil; return end
	-- MouseMovement Delta stays 0 with a free cursor (2026-10-06 Studio playtest), so measure the cursor itself.
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local last = drag.Last or pos
	drag.Last = pos
	local dx, dy = pos.X - last.X, pos.Y - last.Y
	drag.Distance += math.sqrt(dx * dx + dy * dy)
	drag.X += dx
	drag.Y += dy
	if drag.Distance >= DRAG_THRESHOLD then drag.Moved = true end
end

local function onPrimaryEnded(input, processed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local clicked = drag.Held and not drag.Moved and not processed and not blocked()
	-- Keep an unrendered final drag delta until the next camera step, but never emit a click for it.
	drag.Held = false
	if clicked then cancelDrag(); primaryClick:Fire()
	elseif not drag.Moved then cancelDrag() end
end

local function rotateLook(look, dx, dy)
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	local nextPitch = math.clamp(pitch - dy * RADIANS_PER_PIXEL, -PITCH_LIMIT, PITCH_LIMIT)
	local heading = CFrame.lookAt(Vector3.zero, look)
	return CFrame.Angles(0, -dx * RADIANS_PER_PIXEL, 0)
		* heading * CFrame.Angles(nextPitch - pitch, 0, 0)
end

local function applyDrag()
	if not drag.Held and not drag.Moved then return end
	if blocked() then cancelDrag(); return end
	if not drag.Moved then return end
	if drag.X == 0 and drag.Y == 0 then
		if not drag.Held then cancelDrag() end
		return
	end
	local camera = workspace.CurrentCamera
	local rotation = rotateLook(camera.CFrame.LookVector, drag.X, drag.Y)
	drag.X, drag.Y = 0, 0
	-- Only the direction is changed; Roblox computes the subject position, distance and collision next.
	camera.CFrame = CFrame.new(camera.CFrame.Position) * rotation
	if not drag.Held then cancelDrag() end
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
	cancelDrag()
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
	cancelDrag()
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
	UserInputService.InputChanged:Connect(onPrimaryChanged)
	UserInputService.InputEnded:Connect(onPrimaryEnded)
	UserInputService.WindowFocusReleased:Connect(cancelDrag)
	GuiService.MenuOpened:Connect(cancelDrag)
	RunService:BindToRenderStep("HHC_LeftMouseCamera", Enum.RenderPriority.Camera.Value - 1, applyDrag)
	LocalPlayer.CharacterAdded:Connect(bindCharacter)
	LocalPlayer.CharacterRemoving:Connect(function(removing)
		if character == removing then bindCharacter(nil) end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCharacter(LocalPlayer.Character)
	bindCamera()
end

return CameraFollow
