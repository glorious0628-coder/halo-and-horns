-- tools/fixtures/hero_preview_offline.luau : runs HeroPreview.luau (HERO_SOURCE, put in front by tools/test_hero_preview.py)
-- on small doubles: an Instance tree with signals, UserInputService / Players signals, Enum names, a UIKit with or without
-- the PanelCard part. task.delay does nothing (the character copy is checked in Studio photos, not here).
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. (detail ~= nil and (" :: " .. tostring(detail)) or ""))
	end
end

------------------------------------------------------------------ doubles
local live = 0 -- connections not yet disconnected
local function signal()
	local s = { fns = {} }
	function s:Connect(fn)
		local c = { on = true }
		live += 1
		table.insert(self.fns, { c = c, fn = fn })
		function c:Disconnect()
			if self.on then
				self.on = false
				live -= 1
			end
		end
		return c
	end
	function s:Fire(...)
		for _, e in table.clone(self.fns) do
			if e.c.on then e.fn(...) end
		end
	end
	return s
end

local ISA = {
	ViewportFrame = { "GuiObject" }, Frame = { "GuiObject" }, ImageLabel = { "GuiObject" }, TextLabel = { "GuiObject" },
	ScreenGui = { "LayerCollector" }, BillboardGui = { "LayerCollector" }, Script = { "LuaSourceContainer" },
	LocalScript = { "LuaSourceContainer" }, ModuleScript = { "LuaSourceContainer" }, PointLight = { "Light" },
	SpotLight = { "Light" }, BodyVelocity = { "BodyMover" }, RopeConstraint = { "Constraint" },
	WeldConstraint = { "Constraint" }, AlignPosition = { "Constraint" }, MeshPart = { "BasePart" }, Part = { "BasePart" },
}
local function newObj(class, props)
	local o = { ClassName = class, Name = class, Children = {}, Attrs = {}, Destroyed = false, ZIndex = 1,
		AbsoluteSize = { X = 200, Y = 240 }, InputBegan = signal(), Changed = {} }
	function o:IsA(c)
		if c == self.ClassName then return true end
		for _, base in ISA[self.ClassName] or {} do
			if base == c then return true end
		end
		return false
	end
	function o:SetAttribute(k, v) self.Attrs[k] = v end
	function o:GetPropertyChangedSignal(p)
		self.Changed[p] = self.Changed[p] or signal()
		return self.Changed[p]
	end
	function o:Destroy()
		self.Destroyed = true
		self.Parent = nil
	end
	for k, v in props or {} do o[k] = v end
	return o
end

local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
end })
local UIS = { InputChanged = signal(), InputEnded = signal() }
local player = { Character = nil, CharacterAdded = signal() }
local warns = {}
local pcard = nil
local kitArt = true
local UIKit = {
	ArtFrame = function(name, props, fb)
		if not kitArt then error("no art") end
		local f = newObj("ImageLabel", { Name = props.Name, Size = props.Size, Part = name, Fallback = fb })
		pcard = f
		return f
	end,
}
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = player } end
		if n == "UserInputService" then return UIS end
		return { WaitForChild = function(self) return self end }
	end },
	require = function() return { Warn = function(_, m) table.insert(warns, m) end } end,
	Instance = { new = function(class) return newObj(class) end },
	Enum = Enum,
	task = { delay = function() end, defer = function() end, spawn = function() end },
	UDim2 = { new = function(a, b, c, d) return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } } end,
		fromOffset = function(x, y) return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } } end,
		fromScale = function(x, y) return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } } end },
	Color3 = { fromRGB = function(r, g, b) return { r, g, b } end },
	Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
}, { __index = _G })

local f = assert(loadstring(HERO_SOURCE, "=HeroPreview"))
setfenv(f, env)
local H = f()
H.Init({ UIKit = UIKit })
local L, S = H._T.L, H._T.S

------------------------------------------------------------------ 1. pure: what the copy keeps
local function obj(class, name) return newObj(class, { Name = name or class }) end
local kept = {}
for _, o in { obj("Model", "WeaponModel"), obj("Model", "FactionMark"), obj("MeshPart", "Handle"), obj("Accessory", "Hat"),
	obj("WeldConstraint"), obj("Motor6D", "Neck"), obj("Humanoid") } do
	if H.Keep(o) then table.insert(kept, o.Name) end
end
check(#kept == 7, "Keep: the weapon, the halo / horns mark, parts, accessories, welds, joints and the humanoid stay", table.concat(kept, ","))
local dropped = {}
for _, o in { obj("LocalScript"), obj("BillboardGui"), obj("ParticleEmitter"), obj("Sound"), obj("PointLight"), obj("Highlight"),
	obj("Animator"), obj("BodyVelocity"), obj("RopeConstraint"), obj("Tool"), obj("Model", "Nametag"), obj("Part", "GrudgeGhost"),
	obj("Model", "WantedGlow"), obj("Model", "KaijuFire"), obj("ForceField") } do
	if not H.Keep(o) then table.insert(dropped, o.Name) end
end
check(#dropped == 15, "Keep: scripts, UI, effects, sounds, lights, movers, ropes, tools and the name tag / glows / ghost go",
	table.concat(dropped, ","))

------------------------------------------------------------------ 2. pure: the turn and the camera distance
check(H.Turn(0, 50) == 50 * L.DragDeg and H.Turn(350, 50) == (350 + 50 * L.DragDeg) % 360 and H.Turn(10, -100) == (10 - 100 * L.DragDeg) % 360
	and H.Turn(nil, nil) == 0, "Turn: dragged pixels x DragDeg, kept in 0..360")
local t = math.tan(math.rad(30) / 2)
local d1 = H.Distance(2, 5, 1, 30, 0.8)
local r = math.sqrt(5) / 2
check(math.abs(d1 - (math.max(2.5 / t, r / (t * 0.8)) * L.Margin + r)) < 1e-9, "Distance: the height or the turning width, whichever needs more", d1)
check(H.Distance(2, 5, 1, 30, 0.4) > d1 and H.Distance(2, 8, 1, 30, 0.8) > d1 and H.Distance(4, 5, 4, 30, 0.8) > d1,
	"Distance: a narrower view, a taller body, a wider body all step back")
local dWide = H.Distance(6, 2, 6, 30, 0.8)
check(dWide > 6 / 2 / t, "Distance: a body wider than tall fits by its turning width (the staff / a big weapon)", dWide)

------------------------------------------------------------------ 3. Mount: the card, the 3D view, its camera and world
local parent = newObj("ScrollingFrame", { Name = "SlotsView" })
local card = H.Mount(parent, env.UDim2.fromOffset(220, 240))
local view = nil
for _, k in { "Body3D" } do view = S.View and S.View.Name == k and S.View or nil end
check(card ~= nil and card == pcard and card.Part == "PanelCard" and card.Name == "BodyPreview" and card.Parent == parent
	and card.Size.X.Offset == 220, "Mount: the approved PanelCard named BodyPreview, in the given place and size")
check(view ~= nil and view.ClassName == "ViewportFrame" and view.Parent == card and view.Active == true
	and view.BackgroundTransparency == 1 and view.Position.X.Offset == L.Inset and view.Size.X.Offset == -2 * L.Inset,
	"Mount: a see-through ViewportFrame inside the card, inset, taking input")
check(S.Camera and S.Camera.ClassName == "Camera" and S.Camera.Parent == view and view.CurrentCamera == S.Camera
	and S.World and S.World.ClassName == "WorldModel" and S.World.Parent == view, "Mount: its own camera and WorldModel")
check(view and view.Ambient == L.Ambient and view.LightColor == L.Light and view.LightDirection == L.LightDir, "Mount: the view's light")
local liveMounted = live
check(liveMounted == 5, "Mount: drag in / move / end, resize, CharacterAdded (and no character yet)", liveMounted)

------------------------------------------------------------------ 4. drag to turn
local function input(kind, x) return { UserInputType = "UserInputType." .. kind, Position = { X = x, Y = 0 } } end
UIS.InputChanged:Fire(input("MouseMovement", 300))
check(S.Yaw == 0, "a mouse move without a press on the view does not turn it", S.Yaw)
view.InputBegan:Fire(input("MouseButton1", 100))
UIS.InputChanged:Fire(input("MouseMovement", 150))
check(S.Yaw == H.Turn(0, 50), "press on the view + move 50 px = turned", S.Yaw)
UIS.InputChanged:Fire(input("MouseMovement", 130))
check(S.Yaw == H.Turn(H.Turn(0, 50), -20), "moving back turns back (each move from the last point)", S.Yaw)
UIS.InputEnded:Fire(input("MouseButton1", 130))
local y0 = S.Yaw
UIS.InputChanged:Fire(input("MouseMovement", 400))
check(S.Yaw == y0, "let go = the turn stops", S.Yaw)
view.InputBegan:Fire(input("MouseButton2", 100))
UIS.InputChanged:Fire(input("MouseMovement", 200))
check(S.Yaw == y0, "the right button (the camera's) does not turn the body", S.Yaw)
local touch = input("Touch", 50)
view.InputBegan:Fire(touch)
local other = input("Touch", 0)
UIS.InputChanged:Fire(other)
check(S.Yaw == y0, "another finger moving does not turn it", S.Yaw)
touch.Position = { X = 90, Y = 0 }
UIS.InputChanged:Fire(touch)
check(S.Yaw == H.Turn(y0, 40), "the pressing finger turns it", S.Yaw)
UIS.InputEnded:Fire(touch)

------------------------------------------------------------------ 5. a character: its pieces swapped = a new copy asked
local character = newObj("Model", { Name = "Me", ChildAdded = signal(), ChildRemoved = signal() })
player.Character = character
local rev = S.Revision
player.CharacterAdded:Fire(character)
check(S.Revision == rev + 1 and live == liveMounted + 2, "a new character: watched (ChildAdded / ChildRemoved) and copied", live)
character.ChildAdded:Fire(obj("Model", "WeaponModel"))
check(S.Revision == rev + 2, "a weapon model put on = copied again", S.Revision)

------------------------------------------------------------------ 6. Unmount: everything let go
H.Unmount()
check(live == 0, "Unmount disconnects every connection", live)
check(card.Destroyed and S.View == nil and S.World == nil and S.Clone == nil and S.Yaw == 0, "Unmount destroys the card and forgets the view")
local revU = S.Revision
H.Refresh()
check(S.Revision == revU, "Refresh with nothing mounted does nothing")
check(pcall(H.Unmount), "Unmount twice is harmless")

------------------------------------------------------------------ 7. no PanelCard art: a plain frame, still works
kitArt = false
local card2 = H.Mount(parent, env.UDim2.fromOffset(150, 240))
check(card2 and card2.ClassName == "Frame" and card2.Name == "BodyPreview" and card2.Parent == parent and S.View ~= nil,
	"no PanelCard: a plain card, the 3D view still in it")
H.Unmount()
check(live == 0, "and it lets go too", live)

print(string.format("HERO_PREVIEW_SUMMARY checks=%d failed=%d", checks, failed))
