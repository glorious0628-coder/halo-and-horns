-- Offline checks for FirstSteps.luau (A23-68 #1 travel fade, #2 hints in place): the real FirstSteps.luau + Config.luau
-- with small doubles (virtual clock, a Monsters folder, the Fx remote, spies for HUD.Hint / QuestMarker.Focus /
-- Panels.Close). Inputs: CONFIG_SOURCE, STEPS_SOURCE. No Studio / Roblox API calls.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end return nil end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })

local W = { Now = 0, Timers = {}, Hints = {}, Focus = {}, Closed = 0, Tweens = {}, Handler = nil, Warns = {} }
local function advance(dt)
	local target = W.Now + dt
	while true do
		local nextT, idx = math.huge, nil
		for i, t in W.Timers do if t.At <= target and t.At < nextT then nextT, idx = t.At, i end end
		if not idx then break end
		local t = table.remove(W.Timers, idx)
		W.Now = t.At
		t.Fn(table.unpack(t.Args))
	end
	W.Now = target
end

-- instances
local imt = {}
imt.__index = {
	FindFirstChild = function(self, n) for _, c in self.Children do if c.Name == n then return c end end return nil end,
	FindFirstChildOfClass = function(self, cl) for _, c in self.Children do if c.ClassName == cl then return c end end return nil end,
	GetChildren = function(self) return table.clone(self.Children) end,
	IsA = function(self, cl) return self.ClassName == cl or (cl == "BasePart" and self.ClassName == "Part") end,
	GetAttribute = function(self, k) return self.Attrs[k] end,
	SetAttribute = function(self, k, v) self.Attrs[k] = v end,
	WaitForChild = function(self, n) return self:FindFirstChild(n) end,
	Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then for i, c in p.Children do if c == self then table.remove(p.Children, i) break end end end
		rawset(self, "Parent", nil)
		rawset(self, "Destroyed", true)
	end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "Parent")
		if old then for i, c in old.Children do if c == self then table.remove(old.Children, i) break end end end
		rawset(self, "Parent", v)
		if v then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class, name)
	return setmetatable({ ClassName = class, Name = name or class, Children = {}, Attrs = {} }, imt)
end

local playerGui = inst("PlayerGui", "PlayerGui")
local player = inst("Player", "Kid")
player.UserId = 77
playerGui.Parent = player
local character = inst("Model", "Kid")
local root = inst("Part", "HumanoidRootPart")
root.Position = vec(0, 3, 0)
root.Parent = character
player.Character = character
local monsters = inst("Folder", "Monsters")
local function monster(name, pos, owner)
	local m = inst("Model", name)
	local r = inst("Part", "HumanoidRootPart")
	r.Position = pos
	r.Parent = m
	m.PrimaryPart = r
	local h = inst("Humanoid", "Humanoid")
	h.Health = 10
	h.Parent = m
	if owner then m.Attrs.OwnerUserId = owner end
	m.Parent = monsters
	return m
end
local function setAttrs(t) for k, v in t do player.Attrs[k] = v end end

local remote = { OnClientEvent = { Connect = function(_, fn) W.Handler = fn return {} end } }
local registry = {
	HUD = { Hint = function(kind) table.insert(W.Hints, { kind, W.Now }) end },
	QuestMarker = { Focus = function(m) table.insert(W.Focus, m or false) end },
	Panels = { Close = function() W.Closed += 1 end },
	UIKit = { StyleText = function() end },
}
local services = {
	Players = { LocalPlayer = player },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, n) return { __module = n } end } end },
	TweenService = { Create = function(_, i, _, goal) table.insert(W.Tweens, { Inst = i, Goal = goal, At = W.Now })
		return { Play = function() for k, v in goal do i[k] = v end end } end },
}
local Config
-- the camera double (TravelDone turns it behind my back); CFrame.lookAt records its points
local CAM = { CameraType = "CameraType.Scriptable", CFrame = { Position = vec(0, 10, 10) }, Focus = { Position = vec(0, 4.5, 0) } }
local cframe = setmetatable({ lookAt = function(p, f) return { Ctor = "lookAt", Args = { p, f }, Position = p } end },
	{ __index = ctor("CFrame") })
local env = setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end },
	workspace = { CurrentCamera = CAM, FindFirstChild = function(_, n) if n == "Monsters" then return monsters end return nil end },
	Vector3 = { new = vec }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { fromScale = function(x, y) return { x, y } end, new = function(...) return { ... } end,
		fromOffset = function(x, y) return { x, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
		fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = cframe, Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum,
	Instance = { new = function(class) return inst(class) end },
	os = { clock = function() return W.Now end, time = os.time },
	task = {
		delay = function(t, fn, ...) table.insert(W.Timers, { At = W.Now + t, Fn = fn, Args = { ... } }) end,
		spawn = function() end, -- Start's loops are driven by the test (HINT.Step)
		wait = function() end,
	},
	warn = function(...) table.insert(W.Warns, table.concat({ ... }, " ")) end, print = function() end,
	require = function(m) if m.__module == "Config" then return Config end return { Get = function() return remote end } end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
Config = cfn()
local sfn = assert(loadstring(STEPS_SOURCE, "=FirstSteps"))
setfenv(sfn, env)
local FS = sfn()
FS.Init(registry)
local TRAVEL, HINT, TXT = FS.Travel, FS.Hint, FS.Text
check(type(TRAVEL) == "table" and type(HINT) == "table", "test aids exposed", "")

local function fx(kind, data) FS.OnFx(kind, data) end
local function gui() return playerGui:FindFirstChild("TravelFade") end

------------------------------------------------------------------ #1 travel fade
fx("Travel", { UserId = 5, To = "SlimeMeadow", T = 3 })
check(gui() == nil, "another player's Travel shows nothing", "")
fx("Travel", { UserId = 77, To = "SlimeMeadow", T = 3 })
local g = gui()
check(g ~= nil and W.Closed == 1, "my Travel builds the fade and closes the guide window", tostring(g) .. " closed " .. W.Closed)
advance(0.01)
local line = g and g:FindFirstChild("Line")
local meadow = Config.Zones.SlimeMeadow.Name
check(line and line.Text == string.format(TXT.Count, string.format(TXT.Travel, meadow), 3), "3: 'Off to Squishy Meadow!  3'", line and line.Text)
advance(1)
check(line and line.Text == string.format(TXT.Count, string.format(TXT.Travel, meadow), 2), "then 2", line and line.Text)
advance(1)
check(line and line.Text == string.format(TXT.Count, string.format(TXT.Travel, meadow), 1), "then 1", line and line.Text)
local black = g and g:FindFirstChild("Black")
check(black and black.BackgroundTransparency == 1, "not black before T - Fade", black and black.BackgroundTransparency)
advance(0.65) -- t = 2.66
check(black and black.BackgroundTransparency == 0, "black from T - Fade (the move happens unseen)", black and black.BackgroundTransparency)
advance(0.5) -- t = 3.16
fx("TravelDone", { UserId = 77 })
check(black and black.BackgroundTransparency == 1 and line.Text == "", "TravelDone lifts the black at once", black and black.BackgroundTransparency)
advance(TRAVEL.FadeIn + 0.2)
check(gui() == nil, "the fade gui goes after the lift", tostring(gui()))
advance(3)
check(gui() == nil and #W.Warns == 0, "no late timer brings it back", #W.Warns)

-- no TravelDone: the time limit lifts it
fx("Travel", { UserId = 77, To = "SlimeMeadow", T = 3 })
g = gui()
advance(3 + TRAVEL.MaxExtra - 0.05)
check(g and g:FindFirstChild("Black").BackgroundTransparency == 0, "still black just before T + MaxExtra", "")
advance(0.1)
check(g:FindFirstChild("Black").BackgroundTransparency == 1, "lifted at T + MaxExtra without TravelDone", "")
advance(1)
check(gui() == nil, "and gone", "")
-- a second Travel while the first runs: the first's timers do not lift the second
fx("Travel", { UserId = 77, To = "SlimeMeadow", T = 3 })
advance(2)
fx("Travel", { UserId = 77, To = "SlimeMeadow", T = 3 })
advance(2.8) -- the first's T + MaxExtra (4.5) has passed; the second is black (2.6) and waiting
g = gui()
check(g and g:FindFirstChild("Black").BackgroundTransparency == 0, "a newer Travel keeps its own timing", g and g:FindFirstChild("Black").BackgroundTransparency)
fx("TravelDone", { UserId = 77 })
advance(1)
-- A23-74 weapon first: the walk to Otto's anvil says where it goes
fx("Travel", { UserId = 77, To = "Crossroads", Spot = "Forge", T = 3 })
advance(0.01)
g = gui()
line = g and g:FindFirstChild("Line")
check(line and line.Text == string.format(TXT.Count, string.format(TXT.Travel, "the Forge"), 3), "the Forge walk: 'Off to the Forge!  3'",
	line and line.Text)
-- 검수 2026-10-08: the server moved me in front of the anvil, facing it (+X), and the camera was left in front of my
-- face: TravelDone turns it behind my back, as far (10) and as high (+3.5) over the new focus as before
root.Position, root.CFrame = vec(10, 3, 0), { LookVector = vec(1, 0, 0) }
CAM.CameraType, CAM.CFrame, CAM.Focus = "CameraType.Custom", { Position = vec(20, 8, 0) }, { Position = vec(10, 4.5, 0) }
fx("TravelDone", { UserId = 77 })
local cf = CAM.CFrame
local behind = cf.Ctor == "lookAt" and cf.Args[1].X == 0 and cf.Args[1].Y == 8 and cf.Args[1].Z == 0 and cf.Args[2].X == 10
	and math.abs(cf.Args[2].Y - 4.5) < 1e-6 and cf.Args[2].Z == 0
check(behind, "TravelDone turns the camera behind my back (same distance and height)",
	cf.Args and string.format("%s,%s,%s", cf.Args[1].X, cf.Args[1].Y, cf.Args[1].Z) or tostring(cf.Ctor))
advance(TRAVEL.Again + 0.01)
check(CAM.CFrame.Args and CAM.CFrame.Args[1].X == 0, "once more a moment later (a late move), still behind", "")
advance(1)
-- the time limit (no TravelDone: no move seen) and a Scriptable camera (the opening) leave the camera alone
CAM.CFrame = { Position = vec(20, 8, 0) }
fx("Travel", { UserId = 77, To = "Crossroads", Spot = "Forge", T = 3 })
advance(3 + TRAVEL.MaxExtra + 0.5)
check(CAM.CFrame.Ctor == nil, "the time limit does not turn the camera", tostring(CAM.CFrame.Ctor))
CAM.CameraType = "CameraType.Scriptable"
fx("Travel", { UserId = 77, To = "Crossroads", Spot = "Forge", T = 3 })
advance(3)
fx("TravelDone", { UserId = 77 })
check(CAM.CFrame.Ctor == nil, "a Scriptable camera is left alone", tostring(CAM.CFrame.Ctor))
advance(1)
CAM.CameraType = "CameraType.Custom"

------------------------------------------------------------------ #2 hints in place
local function step(seconds)
	local t = 0
	while t < seconds - 1e-9 do
		advance(HINT.Tick)
		HINT.Step(W.Now)
		t += HINT.Tick
	end
end
setAttrs({ TutorialStep = 0, Class = "Warrior", WeaponTier = 0, Faction = "Halo", ZoneId = "SlimeMeadow" })
local near = monster("Slime", vec(6, 3, 0), nil) -- inside the punch reach (7 + 2)
step(7)
check(#W.Hints == 0 and #W.Focus == 0, "before the first mission: no hints, no marker", #W.Hints .. "/" .. #W.Focus)
player.Attrs.TutorialStep = 3 -- A23-74: the Forge step comes before the slimes
step(7)
check(#W.Hints == 0 and #W.Focus == 0, "the Forge step (on the way to the first weapon): no hints, no marker", #W.Hints .. "/" .. #W.Focus)
player.Attrs.TutorialStep = 1
step(4)
check(#W.Hints == 0, "no attack hint before Idle s", #W.Hints)
fx("Swing", { UserId = 77 })
step(4.5)
check(#W.Hints == 0, "a swing of mine restarts the wait", #W.Hints)
fx("Swing", { UserId = 5 })
step(1)
check(#W.Hints == 1 and W.Hints[1][1] == "Attack", "Idle s near a monster without my swing -> the attack hint", W.Hints[1] and W.Hints[1][1])
step(10)
check(#W.Hints == 1, "the attack hint shows once", #W.Hints)
-- the marker: mine first, then the nearest
local other = monster("Slime2", vec(3, 3, 0), 999)
local minefar = monster("Slime3", vec(40, 3, 0), 77)
W.Focus = {}
step(1)
check(W.Focus[#W.Focus] == minefar, "the marker prefers my own slime over a nearer one", tostring(W.Focus[#W.Focus] and W.Focus[#W.Focus].Name))
minefar:Destroy()
other:Destroy()
step(1)
check(W.Focus[#W.Focus] == near, "then the nearest", tostring(W.Focus[#W.Focus] and W.Focus[#W.Focus].Name))
local before = #W.Focus
step(2)
check(#W.Focus == before, "the same marker is not re-sent every tick", #W.Focus - before)
player.Attrs.ZoneId = "Crossroads"
step(0.5)
check(W.Focus[#W.Focus] == false, "leaving the meadow clears the marker", tostring(W.Focus[#W.Focus]))
player.Attrs.ZoneId = "SlimeMeadow"
step(1)
check(W.Focus[#W.Focus] == near, "back in the meadow: marked again", "")
-- my first kill: marker off, then the Q hint once
fx("Reward", { Gold = 3, XP = 5 })
check(W.Focus[#W.Focus] == false, "my first kill clears the marker", tostring(W.Focus[#W.Focus]))
advance(1)
check(#W.Hints == 1, "no Q hint after the kill (A23-71: it comes with learning Q at Lv5)", W.Hints[2] and W.Hints[2][1])
fx("Reward", { Gold = 3, XP = 5 })
step(2)
check(#W.Hints == 1 and W.Focus[#W.Focus] == false, "no marker after the kill", #W.Hints)
-- after the first mission everything stays quiet
player.Attrs.TutorialStep = 99
step(6)
check(#W.Hints == 1, "after the first mission: no hints", #W.Hints)

print(string.format("FIRST_STEPS_SUMMARY checks=%d failed=%d", checks, failed))
