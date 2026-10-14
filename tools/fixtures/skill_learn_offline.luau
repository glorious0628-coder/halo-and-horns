-- Offline checks for A23-71 in SkillBar.luau: no skill button before its unlock level, the learn moment while playing
-- (banner, pop, one line on the button, sound), nothing at a save load. The real SkillBar.luau + Config.luau with a
-- permissive UI double. Inputs: CONFIG_SOURCE, BAR_SOURCE. No Studio / Roblox API calls.
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
local SIGNALS = { Activated = true, InputBegan = true, InputEnded = true, InputChanged = true, MouseEnter = true,
	MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true, MouseButton1Click = true, TouchTap = true }
local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	if SIGNALS[k] then local s = signal() rawset(self, k, s) return s end
	return nil
end
imt.methods = {
	FindFirstChild = function(self, n) for _, c in self.Children do if c.Name == n then return c end end return nil end,
	FindFirstChildOfClass = function(self, cl) for _, c in self.Children do if c.ClassName == cl then return c end end return nil end,
	FindFirstChildWhichIsA = function(self, cl) for _, c in self.Children do if c.ClassName == cl then return c end end return nil end,
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

local function run(opts)
	local W = { Announced = {}, Hints = {}, Played = {}, Toasts = {}, Attr = {}, AttrFns = {}, Now = 100, Reduced = opts.Reduced == true,
		Tweens = {}, Delays = {}, FxSounds = {}, SkillReadyOk = true, Settings = { KeyBadges = opts.Badges }, Cards = {},
		SettingsChanged = signal(), KeysChanged = signal() }
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
		Announce = function(text, dur) table.insert(W.Announced, text) end,
		Toast = function(text) table.insert(W.Toasts, text) end,
		ReducedMotion = function() return W.Reduced end,
	}
	local registry = {
		UIKit = kit,
		HUD = { Hint = function(id, text) table.insert(W.Hints, { id, text }) return true end, IsVisible = function() return true end,
			Layout = nil, HintShown = function() return false end },
		-- no SkillLearn file yet; SkillReady's file comes and goes with W.SkillReadyOk
		Audio = { Play = function(e) table.insert(W.Played, e) return e ~= "SkillLearn" and (e ~= "SkillReady" or W.SkillReadyOk) end },
		Fx = { PlaySound = function(n) table.insert(W.FxSounds, n) end },
		Keybinds = { Label = function(action) return ({ SkillQ = "Q", SkillZ = "Z", SkillX = "X" })[action] end,
			IsLive = function() return true end, ShowsKeys = function() return opts.ShowKeys == true end, Changed = W.KeysChanged },
		Settings = { Get = function(k) return W.Settings[k] end, Changed = W.SettingsChanged },
		PauseCard = { Show = function(kind, data) table.insert(W.Cards, { kind, data }) return true end },
	}
	local services = {
		Players = { LocalPlayer = player },
		ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, n) return { __module = n } end } end,
			FindFirstChild = function() return nil end }, -- no Remotes folder: a cast goes nowhere
		RunService = { Heartbeat = signal(), IsStudio = function() return false end },
		TweenService = { Create = function(_, i, _, goal)
			table.insert(W.Tweens, { Inst = i, Before = rawget(i, "Scale"), Goal = goal })
			return { Play = function() for k, v in goal do i[k] = v end end }
		end },
		UserInputService = { TouchEnabled = opts.Touch == true, GetLastInputType = function() return "Keyboard" end },
	}
	local Config
	local util = { Now = function() return W.Now end, Warn = function(...) print("WARN", ...) end }
	local env = setmetatable({
		game = { GetService = function(_, n) return assert(services[n], n) end },
		Vector3 = ctor("Vector3"), Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		UDim2 = { fromOffset = function(x, y) return { X = { Offset = x }, Y = { Offset = y } } end,
			fromScale = function(x, y) return { X = { Scale = x }, Y = { Scale = y } } end,
			new = function(a, b, c, d) return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } } end },
		UDim = { new = function(a, b) return { Scale = a, Offset = b } end },
		Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
			fromHSV = function() return {} end },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
		NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
		ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
		TweenInfo = { new = function(...) return { ... } end }, Enum = enum,
		Instance = { new = function(class) return inst(class) end },
		typeof = function(v) return type(v) end,
		task = { delay = function(t, f, ...) table.insert(W.Delays, { T = t, F = f, A = table.pack(...) }) end,
			spawn = function(f, ...) f(...) end, wait = function() end },
		os = { clock = function() return W.Now end, time = os.time },
		warn = function(...) print("WARN", ...) end, print = function() end,
		require = function(m) if m.__module == "Config" then return Config end return util end,
	}, { __index = getfenv() })
	local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
	setfenv(cfn, env)
	Config = cfn()
	Config.Skills.Unlock = { Q = 5, Z = 15, X = 25 } -- A23-71 numbers (dev2 moves Config there)
	Config.Skills.ZEnabled, Config.Skills.XEnabled = true, true -- every slot in play for this test
	if opts.KeysTip ~= nil then Config.Nudges.KeysTip = opts.KeysTip end -- 검수 10/09: the tip card is off in the real Config
	local bfn = assert(loadstring(BAR_SOURCE, "=SkillBar"))
	setfenv(bfn, env)
	local SB = bfn()
	for k, v in opts.Attr do W.Attr[k] = v end
	SB.Init(registry)
	SB.Start()
	local function set(k, v)
		W.Attr[k] = v
		for _, fn in W.AttrFns[k] or {} do fn() end
	end
	local function holder(slot) return gui:FindFirstChild("SkillBar") and gui:FindFirstChild("SkillBar"):FindFirstChild("Skill" .. slot) end
	W.Beat = services.RunService.Heartbeat
	return SB, W, set, holder
end

-- runs the queued task.delay calls whose delay is between lo and hi s (the rest stay queued)
local function runDelays(W, lo, hi)
	local list, ran = W.Delays, 0
	W.Delays = {}
	for _, d in list do
		if d.T >= lo and d.T <= hi then
			d.F(table.unpack(d.A, 1, d.A.n))
			ran += 1
		else
			table.insert(W.Delays, d)
		end
	end
	return ran
end

local base = { DataLoaded = true, ClassChosen = true, Class = "Warrior", Faction = "Halo", Level = 1, Mana = 100, MaxMana = 100 }
local function copy(t) local c = {} for k, v in t do c[k] = v end return c end

-- 1. before Lv5: no skill button, a key press says when they come
local SB, W, set, holder = run({ Attr = copy(base) })
check(holder("Q") ~= nil and holder("Q").Visible == false, "Lv1: no Q button on the screen (A23-71)", holder("Q") and tostring(holder("Q").Visible))
check(holder("Z").Visible == false and holder("X").Visible == false, "Lv1: no Z / X either", "")
check(SB.Use("Q") == false and W.Toasts[1] == "Skills come at Lv 5", "a Q press before Lv5: 'Skills come at Lv 5'", W.Toasts[1])
SB.Use("Q")
check(#W.Toasts == 1, "that toast is not spammed", #W.Toasts)
-- 2. Lv5 while playing: the learn moment
set("Level", 5)
check(holder("Q").Visible == true, "Lv5: the Q button appears", tostring(holder("Q").Visible))
check(#W.Announced == 0, "A23-191: no 'New skill!' banner", W.Announced[1])
check(#W.Hints == 0, "검수 10/09: no line on the new button at once", #W.Hints)
check(#W.Played == 0, "the learn sound waits for the level-up chime", table.concat(W.Played, ","))
check(runDelays(W, 1.0, 1.2) == 1, "the learn sound comes about 1.1 s after the level up (sound_gaps A9)", #W.Delays)
check(W.Played[1] == "SkillLearn" and W.Played[2] == "PowerUp", "the SkillLearn sound (PowerUp until its file exists)", table.concat(W.Played, ","))
local popped = false
for _, t in W.Tweens do
	if t.Inst.Name == "LearnPop" and not t.Inst.Destroyed and type(t.Before) == "number" and t.Before < 0.5 and t.Goal.Scale == 1 then popped = true end
end
check(popped, "the button pops in (small -> full size)", #W.Tweens)
check(runDelays(W, 44, 46) == 0 and #W.Hints == 0, "A23-191: no 'Press Q' line later either", #W.Hints)
set("Level", 6)
check(#W.Announced == 0 and #W.Hints == 0, "Lv6: nothing new", #W.Announced)
check(holder("Z").Visible == false, "Z still hidden at Lv6", "")
set("Level", 15)
runDelays(W, 44, 46)
check(holder("Z").Visible == true and #W.Announced == 0 and #W.Hints == 0
	and holder("Z"):FindFirstChild("LearnPop") ~= nil, "Lv15: Z pops in the same way, no words", #W.Hints)

-- 3. a save loading past the level: nothing
local b2 = copy(base)
b2.DataLoaded, b2.Level = false, 1
local SB2, W2, set2, holder2 = run({ Attr = b2 })
set2("Level", 30)
set2("DataLoaded", true)
check(holder2("Q").Visible == true and holder2("X").Visible == true, "a loaded Lv30 save shows its skills", "")
check(#W2.Announced == 0 and #W2.Hints == 0 and holder2("Q"):FindFirstChild("LearnPop") == nil and #W2.Delays == 0,
	"a save load shows no learn moment (no pop, no sound)", #W2.Delays)

-- 3b. dev2 SkillSlots: a rebirth back at Lv1 keeps its skills (the slots never go down); slots open what the level does not
local b4 = copy(base)
b4.SkillSlots = 3
local SB4, W4, set4, holder4 = run({ Attr = b4 })
check(holder4("Q").Visible and holder4("Z").Visible and holder4("X").Visible, "SkillSlots 3 at Lv1 (after a rebirth): all three shown", "")
check(#W4.Announced == 0, "no learn moment for skills I already had", #W4.Announced)
local b5 = copy(base)
b5.SkillSlots = 0
local SB5, W5, set5, holder5 = run({ Attr = b5 })
set5("SkillSlots", 1)
check(holder5("Q").Visible == true and holder5("Q"):FindFirstChild("LearnPop") ~= nil and #W5.Announced == 0
	and holder5("Z").Visible == false, "the server opening slot 1 (SkillSlots 1) pops Q in, Z stays hidden", #W5.Announced)
pcall(SB5.Use, "Q")
runDelays(W5, 44, 46)
check(#W5.Hints == 0, "검수 10/09: Q used within 45 s -> the learn line never comes", #W5.Hints)

-- 3c. sound_gaps A10: a cooldown ending plays SkillReady (Fx's Click only while SkillReady has no file)
do
	local b6 = copy(base)
	b6.Level = 5
	local SB6, W6, set6 = run({ Attr = b6 })
	local function beat() W6.Beat:Fire(0.2) end
	set6("SkillReadyAt", W6.Now + 2)
	beat()
	W6.Now += 3
	table.clear(W6.Played)
	beat()
	check(W6.Played[#W6.Played] == "SkillReady" and #W6.FxSounds == 0, "a cooldown end plays SkillReady, no extra click",
		table.concat(W6.Played, ",") .. " / " .. table.concat(W6.FxSounds, ","))
	W6.SkillReadyOk = false
	set6("SkillReadyAt", W6.Now + 2)
	beat()
	W6.Now += 3
	beat()
	check(W6.FxSounds[1] == "Click", "no SkillReady file yet: Fx's Click stands in", table.concat(W6.FxSounds, ","))
	beat()
	check(#W6.FxSounds == 1, "a ready button stays quiet", #W6.FxSounds)
end

-- 4. phones: no line either (A23-191); reduced motion: no pop
local SB3, W3, set3, holder3 = run({ Attr = copy(base), Touch = true, Reduced = true })
set3("Level", 5)
runDelays(W3, 44, 46)
check(#W3.Hints == 0, "phones: no 'Tap the new button' line (A23-191)", W3.Hints[1] and W3.Hints[1][2])
check(holder3("Q"):FindFirstChild("LearnPop") == nil, "reduced motion: no pop", "")

-- 5. A23-78 / 검수 10/08: the skill key badge follows Settings.KeyBadges ('Key hints', off by default) at once
do
	local b7 = copy(base)
	b7.Level = 5
	local _, W7, _, holder7 = run({ Attr = b7, ShowKeys = true, Badges = false })
	local key = holder7("Q") and holder7("Q"):FindFirstChild("Key")
	check(key ~= nil and key.Visible == false, "Key hints off (A23-78 default): no Q badge on the skill button",
		key and tostring(key.Visible))
	W7.Settings.KeyBadges = true
	W7.SettingsChanged:Fire()
	check(key ~= nil and key.Visible == true and key.Text == "Q", "Key hints on: the Q badge shows at once (Settings.Changed)",
		key and (tostring(key.Visible) .. " " .. tostring(key.Text)))
	W7.Settings.KeyBadges = false
	W7.KeysChanged:Fire()
	check(key ~= nil and key.Visible == false, "Key hints off again: hidden (also redrawn on a key change)", key and tostring(key.Visible))
end

-- 6. A23-191 (user 10/14): no keys tip card at all (A23-81's tip stays in Help), even with the old switch on
do
	local SB7, W7, set7 = run({ Attr = copy(base), KeysTip = true })
	set7("Level", 5)
	SB7.Use("Q")
	runDelays(W7, 0, 30)
	check(#W7.Cards == 0, "no keys tip card (A23-191)", #W7.Cards)
end

print(string.format("SKILL_LEARN_SUMMARY checks=%d failed=%d", checks, failed))
