-- HeroPreview.luau : the Hero window's 3D body (최종 검수 10/13, ref_rpg_ui #3; BB8b). A ViewportFrame + WorldModel holding
-- an anchored copy of my character as it stands now - clothes, the weapon, the halo / horns - on the approved PanelCard.
-- Drag left / right on it to turn it. No words, no new art.
--   CharacterUI: HeroPreview.Mount(parent, size) under the gear cells, HeroPreview.Refresh() when my look may have changed
--   (weapon, side, class, size), HeroPreview.Unmount() when the window closes.
-- HUD's L.RefreshPortrait (the Lv ring's bust) is the same copy idea; this one keeps the WeaponModel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local HeroPreview = {}
local C = nil
local TAG = "HeroPreview"
local LocalPlayer = Players.LocalPlayer

local L = {
	Fov = 30, -- the camera's angle (degrees)
	Margin = 1.08, -- space round the body
	DragDeg = 0.6, -- degrees turned per pixel dragged
	Debounce = 0.3, -- s: a burst of changes (a weapon swap: old model out, new one in) copies once
	Inset = 6, -- du between the card's edge and the 3D view
	Ambient = Color3.fromRGB(185, 185, 200), Light = Color3.fromRGB(255, 248, 235), LightDir = Vector3.new(-0.6, -1, -0.8),
	Card = Color3.fromRGB(16, 20, 40), -- the PanelCard fallback colour
	-- CharacterVisuals pieces left out of the copy: the name tag and glows / the grudge ghost (big see-through shapes)
	Drop = { Nametag = true, GrudgeGhost = true, WantedGlow = true, KaijuFire = true },
	-- classes the copy never keeps (scripts, UI, sounds, effects, movers: HUD's portrait rule; the weapon is a Model, it stays)
	Gone = { "LuaSourceContainer", "LayerCollector", "GuiObject", "Tool", "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke",
		"Sparkles", "Sound", "Light", "Highlight", "BodyMover", "Animator", "AnimationController", "ForceField" },
}

local S = {
	Card = nil, View = nil, Camera = nil, World = nil, Clone = nil, Root = nil, Box = nil,
	Yaw = 0, -- degrees from my front (0 = facing the viewer)
	Revision = 0,
	Conns = {}, -- input + CharacterAdded while mounted
	CharConns = {}, -- the character's ChildAdded / ChildRemoved (a weapon or a mark swapped)
	Character = nil,
	Drag = nil, -- the input dragging (mouse button 1 / a touch)
}

---------------------------------------------------------------------------------------------------- pure
-- does the copy keep this instance? (no Drop piece, no Gone class, no physics constraint but welds)
function HeroPreview.Keep(inst)
	if L.Drop[inst.Name] then return false end
	for _, cls in L.Gone do
		if inst:IsA(cls) then return false end
	end
	if inst:IsA("Constraint") and not inst:IsA("WeldConstraint") then return false end
	return true
end

-- the turn after dragging dx pixels (degrees, kept in 0..360)
function HeroPreview.Turn(yaw, dx)
	return ((tonumber(yaw) or 0) + (tonumber(dx) or 0) * L.DragDeg) % 360
end

-- how far the camera sits so a body w wide, h high, d deep - turned any way - fits a view of fov degrees at aspect
-- (width / height). The widest it gets while it turns is its diagonal
function HeroPreview.Distance(w, h, d, fov, aspect)
	local t = math.tan(math.rad(fov) / 2)
	local r = math.sqrt(w * w + d * d) / 2
	local need = math.max(h / 2 / t, r / (t * math.max(0.1, aspect)))
	return need * L.Margin + r
end

---------------------------------------------------------------------------------------------------- the copy
local function disconnect(list)
	for _, c in list do pcall(function() c:Disconnect() end) end
	table.clear(list)
end

-- source -> copy for every descendant (duplicate names matched by class / name / turn; HUD's L.PortraitPairs)
local function pairUp(source, copy, out)
	out[source] = copy
	local children, used = {}, {}
	for _, child in copy:GetChildren() do
		local key = child.ClassName .. "/" .. child.Name
		children[key] = children[key] or {}
		table.insert(children[key], child)
	end
	for _, child in source:GetChildren() do
		local key = child.ClassName .. "/" .. child.Name
		used[key] = (used[key] or 0) + 1
		local target = children[key] and children[key][used[key]]
		if target then pairUp(child, target, out) end
	end
end

-- the seen parts' box in the root's own space (lo, hi), so the turn is about my body's middle
local function bounds(copy, root)
	local lo, hi = nil, nil
	local base = root.CFrame
	for _, p in copy:GetDescendants() do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 0.95 then
			local cf, half = base:ToObjectSpace(p.CFrame), p.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local v = cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)
						lo = lo and Vector3.new(math.min(lo.X, v.X), math.min(lo.Y, v.Y), math.min(lo.Z, v.Z)) or v
						hi = hi and Vector3.new(math.max(hi.X, v.X), math.max(hi.Y, v.Y), math.max(hi.Z, v.Z)) or v
					end
				end
			end
		end
	end
	return lo, hi
end

local function placeCamera()
	local root, box, view, camera = S.Root, S.Box, S.View, S.Camera
	if not (root and box and view and camera) then return end
	local size = box.Hi - box.Lo
	local mid = (box.Lo + box.Hi) / 2
	local abs = view.AbsoluteSize
	local aspect = (abs.Y > 0) and abs.X / abs.Y or 0.8
	local dist = HeroPreview.Distance(size.X, size.Y, size.Z, L.Fov, aspect)
	-- my front is the root's -Z; the camera stands in front and goes round as I drag
	local at = mid + CFrame.Angles(0, math.rad(S.Yaw), 0):VectorToWorldSpace(Vector3.new(0, 0, -dist))
	local base = root.CFrame
	camera.FieldOfView = L.Fov
	camera.CFrame = CFrame.lookAt(base * at, base * mid, base.UpVector)
	view:SetAttribute("Yaw", S.Yaw)
end

local function rebuild(revision)
	if S.Revision ~= revision or not S.World then return end
	if S.Clone then pcall(function() S.Clone:Destroy() end) end
	S.Clone, S.Root, S.Box = nil, nil, nil
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and character.Parent and root and root:IsA("BasePart")) then return end
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = archivable
	if not ok or not copy then return end
	copy.Name = "PreviewCharacter"
	local map = {}
	pairUp(character, copy, map)
	-- unparented until every script / effect is out; the parts stand still where they are now (the pose of this moment)
	for source, target in map do
		if not HeroPreview.Keep(target) then
			pcall(function() target:Destroy() end)
		elseif target:IsA("BasePart") then
			target.Anchored = true
			target.CanCollide = false
			target.CanTouch = false
			target.CanQuery = false
			target.LocalTransparencyModifier = 0
			target.CFrame = source.CFrame
		elseif target:IsA("Motor6D") or target:IsA("Bone") then
			pcall(function() target.Transform = source.Transform end)
		elseif target:IsA("Humanoid") then
			target.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			target.AutoRotate = false
		end
	end
	for _, o in copy:GetDescendants() do
		if o:IsA("ObjectValue") and o.Value and not o.Value:IsDescendantOf(copy) then o.Value = nil end
	end
	local copyRoot = map[root]
	if not (copyRoot and copyRoot:IsDescendantOf(copy)) then copy:Destroy(); return end
	local lo, hi = bounds(copy, copyRoot)
	if not lo then copy:Destroy(); return end
	copy.Parent = S.World
	S.Clone, S.Root, S.Box = copy, copyRoot, { Lo = lo, Hi = hi }
	placeCamera()
end

-- copies me again after L.Debounce (several calls in a row = one copy)
function HeroPreview.Refresh()
	if not S.View then return end
	S.Revision += 1
	local revision = S.Revision
	task.delay(L.Debounce, function()
		local ok, err = pcall(rebuild, revision)
		if not ok then Util.Warn(TAG, "preview failed: " .. tostring(err)) end
	end)
end

local function watchCharacter()
	local character = LocalPlayer.Character
	if S.Character == character then return end
	disconnect(S.CharConns)
	S.Character = character
	if character then
		-- CharacterVisuals swaps whole pieces (WeaponModel, FactionMark) as direct children; a child the copy would drop
		-- anyway (a fight's Highlight, a Sound) asks nothing (API review 10/13)
		local function changed(child)
			if HeroPreview.Keep(child) then HeroPreview.Refresh() end
		end
		table.insert(S.CharConns, character.ChildAdded:Connect(changed))
		table.insert(S.CharConns, character.ChildRemoved:Connect(changed))
	end
end

---------------------------------------------------------------------------------------------------- the card
-- the card (PanelCard) with the 3D view; replaces an earlier one
function HeroPreview.Mount(parent, size)
	HeroPreview.Unmount()
	local kit = C and C.UIKit
	local card = nil
	if type(kit) == "table" and type(kit.ArtFrame) == "function" then
		local ok, f = pcall(kit.ArtFrame, "PanelCard", { Name = "BodyPreview", Size = size }, { BackgroundColor3 = L.Card })
		if ok then card = f end
	end
	if not card then
		card = Instance.new("Frame")
		card.Name = "BodyPreview"
		card.Size = size
		card.BackgroundColor3 = L.Card
	end
	card.Parent = parent
	local view = Instance.new("ViewportFrame")
	view.Name = "Body3D"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(L.Inset, L.Inset)
	view.Size = UDim2.new(1, -2 * L.Inset, 1, -2 * L.Inset)
	view.Ambient = L.Ambient
	view.LightColor = L.Light
	view.LightDirection = L.LightDir
	view.ZIndex = card.ZIndex + 1
	view.Active = true
	view.Parent = card
	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = L.Fov
	camera.Parent = view
	view.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = view
	S.Card, S.View, S.Camera, S.World = card, view, camera, world
	-- drag to turn: press on the view, move anywhere, let go anywhere
	table.insert(S.Conns, view.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			S.Drag = { Input = input, X = input.Position.X }
		end
	end))
	table.insert(S.Conns, UserInputService.InputChanged:Connect(function(input)
		local d = S.Drag
		if not d then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == d.Input) then
			S.Yaw = HeroPreview.Turn(S.Yaw, input.Position.X - d.X)
			d.X = input.Position.X
			placeCamera()
		end
	end))
	table.insert(S.Conns, UserInputService.InputEnded:Connect(function(input)
		local d = S.Drag
		if d and (input == d.Input or input.UserInputType == Enum.UserInputType.MouseButton1) then S.Drag = nil end
	end))
	table.insert(S.Conns, view:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeCamera))
	table.insert(S.Conns, LocalPlayer.CharacterAdded:Connect(function()
		watchCharacter()
		HeroPreview.Refresh()
	end))
	watchCharacter()
	HeroPreview.Refresh()
	return card
end

-- takes the card away (the window closed); the next Mount starts facing me again
function HeroPreview.Unmount()
	S.Revision += 1
	disconnect(S.Conns)
	disconnect(S.CharConns)
	if S.Card then pcall(function() S.Card:Destroy() end) end
	S.Card, S.View, S.Camera, S.World, S.Clone, S.Root, S.Box = nil, nil, nil, nil, nil, nil, nil
	S.Character, S.Drag, S.Yaw = nil, nil, 0
end

HeroPreview._T = { L = L, S = S } -- tools/test_hero_preview.py

function HeroPreview.Init(registry)
	C = registry
end

function HeroPreview.Start() end

return HeroPreview
