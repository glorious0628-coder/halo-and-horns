-- Offline checks for gameplay_plan 2-C #8 in SkillBar.luau: the server's Fx "SkillPress" refusals shake the button with
-- one short word (Config.Skills.Text), "Queued" says nothing, and the X hop prep (Fx "Hop" { To, T } moves my own
-- character along a low arc to To at its ground height; far / broken / dead = no move). The real SkillBar.luau +
-- Config.luau with small doubles (Remotes.Fx, the character, workspace:Raycast ground). Inputs: CONFIG_SOURCE, BAR_SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function signal()
	local s = { Fns = {} }
	function s:Connect(f) table.insert(self.Fns, f) return { Disconnect = function() end } end
	function s:Fire(...) for _, f in self.Fns do f(...) end end
	return s
end

-- Vector3 / CFrame
local vmt = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __v3 = true }, vmt) end
vmt.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__index = function(self, k)
	if k == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z) end
	return nil
end
local cmt = {}
local function cf(pos, rot) return setmetatable({ Position = pos, Rot = rot or "facing" }, cmt) end
cmt.__index = function(self, k) if k == "Rotation" then return cf(v3(0, 0, 0), rawget(self, "Rot")) end return nil end
cmt.__add = function(a, b) return cf(b, rawget(a, "Rot")) end

local SIGNALS = { Activated = true, InputBegan = true, InputEnded = true, InputChanged = true, MouseEnter = true,
	MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true, MouseButton1Click = true, TouchTap = true,
	OnClientEvent = true }
local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	if SIGNALS[k] then local s = signal() rawset(self, k, s) return s end
	if k == "Position" and rawget(self, "CFrame") then return rawget(self, "CFrame").Position end
	return nil
end
imt.methods = {
	FindFirstChild = function(self, n) for _, c in self.Children do if c.Name == n then return c end end return nil end,
	FindFirstChildOfClass = function(self, cl) for _, c in self.Children do if c.ClassName == cl then return c end end return nil end,
	FindFirstChildWhichIsA = function(self, cl) for _, c in self.Children do if c.ClassName == cl then return c end end return nil end,
	WaitForChild = function(self, n) for _, c in self.Children do if c.Name == n then return c end end return nil end,
	GetChildren = function(self) return table.clone(self.Children) end,
	GetDescendants = function(self) return table.clone(self.Children) end,
	IsA = function(self, cl) return self.ClassName == cl end,
	Destroy = function(self) rawset(self, "Destroyed", true) end,
	GetPropertyChangedSignal = function(self, k) self.__sig = self.__sig or {} self.__sig[k] = self.__sig[k] or signal() return self.__sig[k] end,
	ClearAllChildren = function(self) table.clear(self.Children) end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		rawset(self, "Parent", v)
		if type(v) == "table" and v.Children then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class, props, kids)
	local o = setmetatable({ ClassName = class, Name = class, Children = {} }, imt)
	for k, v in props or {} do if k ~= "Parent" then rawset(o, k, v) end end
	for _, c in kids or {} do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end

local W = { Attr = {}, AttrFns = {}, Now = 100, Played = {}, Ground = 0, Rays = 0 }
local player = { UserId = 7, GetAttribute = function(_, k) return W.Attr[k] end }
local gui = inst("ScreenGui", { Name = "MainGui" })
local kit = {
	Gui = gui,
	Create = function(class, props, kids) return inst(class, props, kids) end,
	StyledLabel = function(props) return inst("TextLabel", props) end,
	LightText = function() end, ButtonFeel = function() end,
	ArtId = function() return nil end, ArtPart = function() return nil end,
	ArtImage = function() return nil end, ArtFrame = function() return nil end,
	OnAttr = function(keys, fn) for _, k in keys do W.AttrFns[k] = W.AttrFns[k] or {} table.insert(W.AttrFns[k], fn) end end,
	Announce = function() end, Toast = function() end, ReducedMotion = function() return true end,
}
local registry = {
	UIKit = kit,
	HUD = { Hint = function() return true end, IsVisible = function() return true end, Layout = nil, HintShown = function() return false end },
	Audio = { Play = function(e) table.insert(W.Played, e) return true end },
	Fx = { PlaySound = function() end },
	Keybinds = { Label = function(a) return ({ SkillQ = "Q", SkillZ = "Z", SkillX = "X" })[a] end, IsLive = function() return true end,
		ShowsKeys = function() return false end, Changed = signal() },
	Settings = { Get = function() return nil end, Changed = signal() },
}
local remotes = inst("Folder", { Name = "Remotes" })
local FX = inst("RemoteEvent", { Name = "Fx", Parent = remotes })
local HEART = signal()
local services = {
	Players = { LocalPlayer = player },
	ReplicatedStorage = { WaitForChild = function(_, n)
		if n == "Remotes" then return remotes end
		return { WaitForChild = function(_, m) return { __module = m } end }
	end, FindFirstChild = function(_, n) return n == "Remotes" and remotes or nil end },
	RunService = { Heartbeat = HEART, IsStudio = function() return false end },
	TweenService = { Create = function(_, i, _, goal) return { Play = function() for k, v in goal do i[k] = v end end } end },
	UserInputService = { TouchEnabled = false, GetLastInputType = function() return "Keyboard" end },
}
-- my character on flat ground (W.Ground = the ground's Y under any point unless W.GroundAt says otherwise)
local char = inst("Model", { Name = "Me" })
local root = inst("Part", { Name = "HumanoidRootPart", Parent = char })
root.CFrame = cf(v3(0, 3, 0))
local hum = inst("Humanoid", { Health = 100, Parent = char })
player.Character = char
local Config
local util = { Now = function() return W.Now end, Warn = function(...) print("WARN", ...) end }
local env = setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end },
	workspace = { Raycast = function(_, origin, dir)
		W.Rays += 1
		local g = W.GroundAt and W.GroundAt(origin) or W.Ground
		if g == nil then return nil end
		return { Position = v3(origin.X, g, origin.Z) }
	end },
	RaycastParams = { new = function() return {} end },
	Vector3 = { new = v3, zero = v3(0, 0, 0) }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { fromOffset = function(x, y) return { X = { Offset = x }, Y = { Offset = y } } end,
		fromScale = function(x, y) return { X = { Scale = x }, Y = { Scale = y } } end,
		new = function(a, b, c, d) return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } } end },
	UDim = { new = function(a, b) return { Scale = a, Offset = b } end },
	Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
		fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = { new = function(p) return cf(p, "none") end }, Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum,
	Instance = { new = function(class) return inst(class) end },
	typeof = function(v)
		if type(v) == "table" and rawget(v, "__v3") then return "Vector3" end
		if type(v) == "table" and rawget(v, "ClassName") then return "Instance" end
		return type(v)
	end,
	task = { delay = function() end, spawn = function(f, ...) f(...) end, wait = function() end },
	os = { clock = function() return W.Now end, time = os.time },
	warn = function(...) print("WARN", ...) end, print = function() end,
	require = function(m) if m.__module == "Config" then return Config end return util end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
Config = cfn()
Config.Skills.Unlock = { Q = 5, Z = 15, X = 25 }
Config.Skills.ZEnabled, Config.Skills.XEnabled = true, true
local bfn = assert(loadstring(BAR_SOURCE, "=SkillBar"))
setfenv(bfn, env)
local SB = bfn()
for k, v in { DataLoaded = true, ClassChosen = true, Class = "Archer", Faction = "Halo", Level = 30, Mana = 100, MaxMana = 100 } do
	W.Attr[k] = v
end
SB.Init(registry)
SB.Start()
local T = SB._T
local TX = Config.Skills.Text
local function word(slot) local b = T.ui.buttons[slot] return b and b.Word end
local function shown(slot) local w = word(slot) return w and w.Visible == true and w.Text or nil end
local function clear() for _, b in T.ui.buttons do if b.Word then b.Word.Visible = false b.Word.Text = "" end end end
local function fx(kind, data) FX.OnClientEvent:Fire(kind, data) end

-- 0) wiring + words
check(#FX.OnClientEvent.Fns == 1, "listens to Fx (Remotes)", #FX.OnClientEvent.Fns)
check(TX.NotReady == "Not ready" and TX.NotNow == "Not now" and TX.NoMP == "Not enough MP" and TX.NoTarget == "No target",
	"the short words live in Config.Skills.Text", tostring(TX.NotReady))
check(T.ui.buttons.Q and T.ui.buttons.Z and T.ui.buttons.X, "three buttons built", "")

-- 1) server refusals
fx("SkillPress", { Slot = "Z", Result = "NoTarget" })
check(shown("Z") == TX.NoTarget, "no target: 'No target' over Z", shown("Z"))
clear()
fx("SkillPress", { Slot = "X", Result = "CantHop" })
check(shown("X") == TX.CantHop, "can't hop: its word over X", shown("X"))
clear()
fx("SkillPress", { Slot = "X", Result = "TooHeavy" })
check(shown("X") == TX.TooHeavy, "too heavy: its word", shown("X"))
clear()
fx("SkillPress", { Slot = "Q", Result = "Cooldown" })
check(shown("Q") == TX.NotReady, "the server's cooldown: 'Not ready'", shown("Q"))
clear()
local played = #W.Played
fx("SkillPress", { Slot = "Q", Result = "NoMP" })
check(shown("Q") == TX.NoMP and W.Played[#W.Played] == "No" and #W.Played == played + 1, "the server's MP: 'Not enough MP' + the No sound", shown("Q"))
clear()
fx("SkillPress", { Slot = "Z", Result = "Locked" })
check(shown("Z") == TX.NotNow, "a switched-off slot: 'Not now'", shown("Z"))
clear()
fx("SkillPress", { Slot = "Z", Result = "Queued" })
check(shown("Z") == nil, "Queued says nothing", shown("Z"))
fx("SkillPress", { Slot = "V", Result = "NoTarget" })
fx("SkillPress", "junk")
fx("SkillPress", { Slot = "Z", Result = "Weird" })
check(shown("Z") == nil and shown("Q") == nil and shown("X") == nil, "unknown slots / results / junk show nothing", "")
-- a locked slot (level too low) refused as Locked reads its unlock level
W.Attr.Level, W.Attr.SkillSlots = 20, 2
for _, fn in W.AttrFns.Level or {} do fn() end
fx("SkillPress", { Slot = "X", Result = "Locked" })
check(shown("X") == string.format("Unlocks at Lv %d", 25), "a slot below its level: 'Unlocks at Lv 25'", shown("X"))
clear()
W.Attr.Level, W.Attr.SkillSlots = 30, 3
for _, fn in W.AttrFns.Level or {} do fn() end
-- the client's own refusal words come from the same table
W.Attr.SkillReadyAtZ = W.Now + 5
SB.Use("Z")
check(shown("Z") == TX.NotReady, "the client's own cooldown refusal: 'Not ready' (Config)", shown("Z"))
clear()
W.Attr.SkillReadyAtZ = 0
-- a refused press drops the press waiting behind it
T.S.queued = "Z"
fx("SkillPress", { Slot = "Z", Result = "NoTarget" })
check(T.S.queued == nil, "a refusal clears the waiting press of that slot", tostring(T.S.queued))
clear()

-- 2) the X hop
check(SB.HopLanding(v3(0, 3, 0), v3(10, 3, 0), 0, 2).Y == 5, "landing: To's ground + my height over the ground I left", SB.HopLanding(v3(0, 3, 0), v3(10, 3, 0), 0, 2).Y)
check(SB.HopLanding(v3(0, 3, 0), v3(10, 9, 0), nil, 2).Y == 9, "landing: no ground found = To as sent", "")
local mid = SB.HopPoint(v3(0, 3, 0), v3(10, 3, 0), 0.5, 1.5)
check(mid.X == 5 and mid.Y == 4.5 and SB.HopPoint(v3(0, 3, 0), v3(10, 3, 0), 1, 1.5).Y == 3, "arc: highest in the middle, lands on To", mid.Y)
fx("Hop", { To = v3(10, 3, 0), T = 0.25 })
check(T.HOP.Live ~= nil, "Fx Hop starts a hop", "")
W.Now += 0.125
HEART:Fire(0.016)
local p = root.CFrame.Position
check(p.X > 4 and p.X < 6 and p.Y > 3, "half way: in the air over the middle", p.X .. "," .. p.Y)
check(root.CFrame.Rot == "facing", "the hop keeps my facing", root.CFrame.Rot)
W.Now += 0.2
HEART:Fire(0.016)
p = root.CFrame.Position
check(T.HOP.Live == nil and p.X == 10 and p.Y == 3 and root.AssemblyLinearVelocity ~= nil, "done: on To, still", p.X .. "," .. p.Y)
root.CFrame = cf(v3(0, 3, 0))
-- uphill: To's ground 2 studs higher
W.GroundAt = function(o) return o.X > 5 and 2 or 0 end
fx("Hop", { To = v3(10, 3, 0), T = 0.25 })
W.Now += 1
HEART:Fire(0.016)
check(root.CFrame.Position.Y == 5, "uphill landing stands on the ground (no sinking in)", root.CFrame.Position.Y)
W.GroundAt = nil
root.CFrame = cf(v3(0, 3, 0))
fx("Hop", { To = v3(40, 3, 0), T = 0.25 })
check(T.HOP.Live == nil, "a far To (over the hop length) does not move me", "")
fx("Hop", { To = "x" })
fx("Hop", nil)
check(T.HOP.Live == nil, "broken hops do nothing", "")
hum.Health = 0
fx("Hop", { To = v3(8, 3, 0) })
check(T.HOP.Live == nil, "no hop while knocked out", "")
hum.Health = 100
fx("Hop", { To = v3(8, 3, 0), T = 0.25 })
player.Character = inst("Model")
W.Now += 0.1
HEART:Fire(0.016)
check(T.HOP.Live == nil and root.CFrame.Position.X == 0, "a new character stops the hop", root.CFrame.Position.X)
player.Character = char

print(("SKILL_PRESS_SUMMARY checks=%d failed=%d"):format(checks, failed))
