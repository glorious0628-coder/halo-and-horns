-- Offline checks for PauseCard.luau (SPEC A23-79 #1: the pause card + Welcome back). The runner (tools/test_pause_card.py)
-- prepends CARD_SOURCE. Roblox is replaced by small doubles: Players.LocalPlayer (attributes, a character with a Humanoid
-- and its HealthChanged), ReplicatedStorage (Shared modules, Remotes.Travel recording FireServer), RunService.Heartbeat,
-- the Fx remote, os.clock (a clock the test moves), task.spawn / task.defer, Instance-like tables (Parent, Children,
-- FindFirstChild, Destroy, Activated), a UIKit double (Gui, Create, ArtFrame, StyledLabel, ArtTextButton recording the
-- part name, ArtImage, ShouldHoldBanners) and IsOpen() doubles for Panels / Intro / pickers / map / Tab list. Every check
-- is named; no Studio, Roblox API or network calls.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end

local NOW = 1000
local DEFERRED = {}
local function flush()
	while #DEFERRED > 0 do
		local fn = table.remove(DEFERRED, 1)
		fn()
	end
end

local function newInst(class)
	local o = { __kind = "Instance", ClassName = class, Name = class, Children = {} }
	if class == "TextButton" or class == "ImageButton" then o.Activated = signal() end
	function o:IsA(c) return c == self.ClassName or c == "Instance" or (c == "GuiObject" and self.ClassName ~= "ScreenGui") end
	function o:FindFirstChild(n, recursive)
		for _, ch in self.Children do
			if ch.Name == n then return ch end
			if recursive then
				local found = ch:FindFirstChild(n, true)
				if found then return found end
			end
		end
		return nil
	end
	function o:GetChildren() return table.clone(self.Children) end
	function o:Destroy() self.Parent = nil end
	return setmetatable(o, { __newindex = function(t, k, v)
		if k == "Parent" then
			local old = rawget(t, "_parent")
			if old then
				local i = table.find(old.Children, t)
				if i then table.remove(old.Children, i) end
			end
			rawset(t, "_parent", v)
			if v then table.insert(v.Children, t) end
			return
		end
		rawset(t, k, v)
	end, __index = function(t, k) if k == "Parent" then return rawget(t, "_parent") end return nil end })
end
local function descendants(root, out)
	out = out or {}
	for _, ch in root.Children do
		table.insert(out, ch)
		descendants(ch, out)
	end
	return out
end

-- the UIKit double
local ART = {} -- parts with art (ArtImage draws them)
local HOLD = false
local BUTTONS = {} -- [name] = { Part, Size, Click }
local Kit = { Gui = newInst("ScreenGui"), Theme = { Good = "good", Bg = "bg", Gold = "gold" } }
function Kit.Create(class, props, children)
	local inst = newInst(class)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, ch in children or {} do ch.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end
function Kit.ArtFrame(name, props, fallback, children) return Kit.Create("Frame", props, children), false end
function Kit.StyledLabel(props) return Kit.Create("TextLabel", props) end
function Kit.ArtImage(name, props)
	if not ART[name] then return nil end
	return Kit.Create("ImageLabel", props)
end
function Kit.ArtTextButton(part, props, onClick)
	local btn = Kit.Create("TextButton", props)
	btn.Part = part
	btn.Activated:Connect(onClick)
	BUTTONS[props.Name] = { Part = part, Size = props.Size, Button = btn }
	return btn
end
function Kit.ShouldHoldBanners() return HOLD end

local OPEN = { Panels = false, Intro = false, FactionPicker = false, ClassPicker = false, WorldMap = false, PlayerListUI = false }
local Cdouble = { UIKit = Kit }
for name in OPEN do
	Cdouble[name] = { IsOpen = function() return OPEN[name] end }
end

-- the player
local HUM = { Health = 100, HealthChanged = signal() }
local CHAR = { FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return HUM end return nil end,
	WaitForChild = function() return HUM end }
local PATTR = { DataLoaded = true }
local LP = { UserId = 7, Character = CHAR, CharacterAdded = signal() }
function LP:GetAttribute(k) return PATTR[k] end

local FX = signal()
local HB = signal()
local TRAVEL = {}
local REMOTE = { IsA = function(_, c) return c == "RemoteEvent" end }
function REMOTE.FireServer(self, zone) table.insert(TRAVEL, zone) end
local REMOTES = { FindFirstChild = function(_, n) if n == "Travel" then return REMOTE end return nil end }
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "RunService" then return { Heartbeat = HB } end
		if n == "ReplicatedStorage" then
			return {
				WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end,
				FindFirstChild = function(_, n2) if n2 == "Remotes" then return REMOTES end return nil end,
			}
		end
		return {}
	end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	Instance = { new = newInst },
	Enum = setmetatable({}, { __index = function(_, t) return setmetatable({}, { __index = function(_, i) return t .. "." .. i end }) end }),
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	Color3 = { new = function(...) return { ... } end, fromRGB = function(...) return { ... } end },
	UDim = { new = function(...) return { ... } end },
	UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end,
		fromOffset = function(x, y) return { "offset", x, y } end },
	os = { clock = function() return NOW end, time = os.time },
	task = { spawn = function(fn, ...) fn(...) end, defer = function(fn, ...)
		local a = table.pack(...)
		table.insert(DEFERRED, function() fn(table.unpack(a, 1, a.n)) end)
	end },
	require = function(m)
		if m.__module == "Net" then return { Get = function(name) if name == "Fx" then return { OnClientEvent = FX } end return {} end } end
		return { Signal = { new = signal }, Warn = function() end }
	end,
}, { __index = getfenv() })
local fn = assert(loadstring(CARD_SOURCE, "=PauseCard"))
setfenv(fn, env)
local Card = fn()
local SHOWN = {}
Card.Shown:Connect(function(kind, button, why) table.insert(SHOWN, { kind, button, why }) end)
Card.Init(Cdouble)
Card.Start()

local function cards()
	local n = 0
	for _, ch in Kit.Gui.Children do if ch.Name == "PauseCard" then n += 1 end end
	return n
end
local function card() return Kit.Gui:FindFirstChild("PauseCard") end
local function text(name) local c = card(); local l = c and c:FindFirstChild(name, true); return l and l.Text end
local function click(name)
	local b = BUTTONS[name]
	if b then b.Button.Activated:Fire() end
	flush()
end
local function reset()
	BUTTONS = {}
	SHOWN = {}
	TRAVEL = {}
end

-- 1) the pause card on a free screen
FX:Fire("PauseCard", { Next = "King Slime (2 of 3)", Why = "Chapter" })
check("a pause card opens at once on a free screen", Card.IsOpen() and cards() == 1, cards())
check("title Saved! and the next goal", text("Title") == "Saved!" and text("Body") == "Next time: King Slime (2 of 3)",
	tostring(text("Title")) .. " | " .. tostring(text("Body")))
local keep, ok = BUTTONS.Keep, BUTTONS.OK
check("[Keep playing] and [OK]: the same size, the same look", keep and ok and keep.Button.Text == "Keep playing"
	and ok.Button.Text == "OK" and keep.Part == ok.Part and keep.Size[2] == ok.Size[2] and keep.Size[3] == ok.Size[3])
local nButtons = 0
for _, d in descendants(card()) do if d.ClassName == "TextButton" then nButtons += 1 end end
check("only those two buttons on the card (no purchase button)", nButtons == 2, nButtons)
check("no 'saved' mark without its art", card():FindFirstChild("Icon", true) == nil)
click("OK")
check("[OK] closes it and tells the metrics", not Card.IsOpen() and cards() == 0 and SHOWN[1] and SHOWN[1][1] == "Pause"
	and SHOWN[1][2] == "OK" and SHOWN[1][3] == "Chapter", #SHOWN)
reset()
Card.Show("Pause", { Next = "Iron Sword" })
click("Keep")
check("[Keep playing] closes it too", not Card.IsOpen() and SHOWN[1] and SHOWN[1][2] == "Keep")
reset()
Card.Show("Pause", {})
check("no goal -> the plain saved line", text("Body") == "Everything is saved.", text("Body"))
card().Activated:Fire()
flush()
check("a tap beside the card closes it (Backdrop)", not Card.IsOpen() and SHOWN[1] and SHOWN[1][2] == "Backdrop")
ART.IconSaved = true
reset()
Card.Show("Pause", { Next = "Lv 10" })
check("the 'saved' mark once its art is wired", card():FindFirstChild("Icon", true) ~= nil)
click("OK")
ART.IconSaved = nil

-- 2) waiting while the screen is busy
local function waits(name, setBusy, setFree)
	reset()
	setBusy()
	Card.Show("Pause", { Next = "Goal" })
	local waited = not Card.IsOpen()
	setFree()
	NOW += 1
	HB:Fire()
	local opened = Card.IsOpen()
	check("waits while " .. name .. ", then opens", waited and opened, tostring(waited) .. "/" .. tostring(opened))
	click("OK")
end
waits("a window is open", function() OPEN.Panels = true end, function() OPEN.Panels = false end)
waits("the intro plays", function() OPEN.Intro = true end, function() OPEN.Intro = false end)
waits("the class picker is open", function() OPEN.ClassPicker = true end, function() OPEN.ClassPicker = false end)
waits("the map is open", function() OPEN.WorldMap = true end, function() OPEN.WorldMap = false end)
waits("knocked out", function() HUM.Health = 0 end, function() HUM.Health = 100 end)
waits("the data is not loaded", function() PATTR.DataLoaded = false end, function() PATTR.DataLoaded = true end)
waits("the first steps hold banners", function() HOLD = true end, function() HOLD = false end)
local popup
waits("a reward popup shows", function() popup = Kit.Create("Frame", { Name = "RewardPopup", Parent = Kit.Gui }) end,
	function() popup:Destroy() end)
local confirm
waits("a confirm box is open", function() confirm = Kit.Create("TextButton", { Name = "ConfirmDialog", Parent = Kit.Gui }) end,
	function() confirm:Destroy() end)
-- hurt: HealthChanged going down, then HurtCalm (5 s)
reset()
HUM.HealthChanged:Fire(80)
HUM.Health = 80
Card.Show("Pause", { Next = "Goal" })
local hurtWait = not Card.IsOpen()
NOW += 2
HB:Fire()
local stillWait = not Card.IsOpen()
NOW += 4
HB:Fire()
check("waits 5 s after a hit (no card in a fight)", hurtWait and stillWait and Card.IsOpen(),
	tostring(hurtWait) .. "/" .. tostring(stillWait) .. "/" .. tostring(Card.IsOpen()))
click("OK")
HUM.Health = 100
-- too old: dropped
reset()
OPEN.Panels = true
Card.Show("Pause", { Next = "Goal" })
NOW += 91
OPEN.Panels = false
HB:Fire()
NOW += 1
HB:Fire()
check("a card that waited over 90 s is dropped", not Card.IsOpen() and cards() == 0)
-- a newer card waits for the open one
reset()
Card.Show("Pause", { Next = "First" })
Card.Show("Pause", { Next = "Second" })
check("one card at a time", cards() == 1 and text("Body") == "Next time: First", cards())
click("OK")
check("the newer card opens after the first closes", Card.IsOpen() and text("Body") == "Next time: Second", text("Body"))
click("OK")
NOW += 1

-- 3) Welcome back
reset()
FX:Fire("WelcomeBack", { Next = "King Slime (2 of 3)", Zone = "SlimeMeadow" })
check("Welcome back with the next goal", text("Title") == "Welcome back!" and text("Body") == "Next: King Slime (2 of 3)",
	tostring(text("Title")) .. " | " .. tostring(text("Body")))
check("[Go] and [OK]: the same size, the same look", BUTTONS.Go and BUTTONS.OK and BUTTONS.Go.Part == BUTTONS.OK.Part
	and BUTTONS.Go.Button.Text == "Go")
click("Go")
check("[Go] asks the server to travel to the zone", TRAVEL[1] == "SlimeMeadow" and not Card.IsOpen() and SHOWN[1]
	and SHOWN[1][1] == "Back" and SHOWN[1][2] == "Go", TRAVEL[1])
reset()
FX:Fire("WelcomeBack", { Next = "Lv 10" })
check("no zone -> only [OK]", BUTTONS.OK ~= nil and BUTTONS.Go == nil)
click("OK")
check("[OK] never travels", #TRAVEL == 0)
reset()
FX:Fire("WelcomeBack", {})
check("no goal -> the plain welcome line", text("Body") == "Good to see you again!", text("Body"))
click("OK")

-- 4) whose card, which kinds, the goal text
reset()
FX:Fire("PauseCard", { Next = "Goal", UserId = 99 })
check("another player's card is not mine", not Card.IsOpen())
FX:Fire("PauseCard", { Next = "Goal", UserId = 7 })
check("my own (UserId) card opens", Card.IsOpen())
click("OK")
FX:Fire("Enhance", { Success = false })
FX:Fire("SomethingElse", { Next = "x" })
check("other Fx kinds open nothing", not Card.IsOpen())
check("an unknown card kind is refused", Card.Show("Shop", { Next = "x" }) == false and not Card.IsOpen())
Card.Show("Pause", { Next = "<b>Iron</b>\nSword" })
check("the goal: no rich-text brackets, no line breaks", text("Body") == "Next time: bIron/b Sword", text("Body"))
click("OK")
Card.Show("Pause", { Next = string.rep("a", 80) })
check("a long goal is cut at 60 with …", text("Body") == "Next time: " .. string.rep("a", 60) .. "…", text("Body"))
click("OK")

-- 5) a tip card (A23-81: the keys tip after the first skill)
reset()
local OPENED = {}
Cdouble.Panels.Open = function(id, arg) table.insert(OPENED, { id, arg }) end
Card.Show("Tip", { Text = "Tip: You can change your keys in Settings!",
	Go = { Text = "Open Settings", Window = "Settings", Arg = { Tab = "Keys" } } })
check("a tip card: 'Tip' and its words", text("Title") == "Tip" and text("Body") == "Tip: You can change your keys in Settings!",
	tostring(text("Title")) .. " | " .. tostring(text("Body")))
check("[Open Settings] and [OK]: the same look", BUTTONS.Go and BUTTONS.OK and BUTTONS.Go.Button.Text == "Open Settings"
	and BUTTONS.Go.Part == BUTTONS.OK.Part)
click("Go")
check("[Open Settings] opens Settings on its Keys tab (no travel)", OPENED[1] and OPENED[1][1] == "Settings" and OPENED[1][2]
	and OPENED[1][2].Tab == "Keys" and #TRAVEL == 0 and not Card.IsOpen())
reset()
check("a tip without words is refused", Card.Show("Tip", { Go = { Text = "Open", Window = "Settings" } }) == false and not Card.IsOpen())
Card.Show("Tip", { Text = "Hello" })
check("a tip without a window: only [OK]", BUTTONS.OK ~= nil and BUTTONS.Go == nil)
click("OK")
check("[OK] on a tip opens nothing", #OPENED == 1)

-- 6) 게임성 개발 3's contract (return_server_2026-10-08.md): the daily card's Tomorrow line + OptIn, [Go] counted
reset()
local CB = {}
Cdouble.ComeBack = { Metric = function(id) table.insert(CB, "Metric:" .. tostring(id)) return true end,
	OptIn = function(why) table.insert(CB, "OptIn:" .. tostring(why)) return true end }
FX:Fire("PauseCard", { Why = "Daily", Next = "Hunt and get stronger!", Tomorrow = "New dailies", OptIn = true })
check("the daily card: the next goal, then tomorrow's line", text("Body") == "Next time: Hunt and get stronger!\nTomorrow: New dailies",
	text("Body"))
check("no opt-in moment while the card is open", #CB == 0, table.concat(CB, ","))
click("OK")
check("the card closed -> the opt-in moment 'Daily', once", #CB == 1 and CB[1] == "OptIn:Daily" and not Card.IsOpen(), table.concat(CB, ","))
table.clear(CB)
FX:Fire("PauseCard", { Why = "Daily", Next = "Goal", Tomorrow = "King Diary page 3", OptIn = false })
check("the King Diary page as tomorrow's line", text("Body") == "Next time: Goal\nTomorrow: King Diary page 3", text("Body"))
click("Keep")
check("OptIn false: no moment", #CB == 0, table.concat(CB, ","))
FX:Fire("PauseCard", { Why = "Daily", Next = "Goal", OptIn = "yes" })
card().Activated:Fire()
flush()
check("OptIn must be true (a string is not)", #CB == 0, table.concat(CB, ","))
FX:Fire("PauseCard", { Why = "Chapter", Next = "Goal", Tomorrow = "<b>" .. string.rep("z", 50) })
check("tomorrow's line cleaned and cut at 40", text("Body") == "Next time: Goal\nTomorrow: b" .. string.rep("z", 39) .. "…", text("Body"))
click("OK")
FX:Fire("PauseCard", { Why = "War", Next = "Goal", Tomorrow = "   " })
check("an empty tomorrow line adds nothing", text("Body") == "Next time: Goal", text("Body"))
click("OK")
FX:Fire("WelcomeBack", { Next = "Goal", Zone = "SlimeMeadow" })
click("Go")
check("[Go] on welcome back counts WelcomeBackGo", #CB == 1 and CB[1] == "Metric:WelcomeBackGo", table.concat(CB, ","))
FX:Fire("WelcomeBack", { Next = "Goal", Zone = "SlimeMeadow" })
click("OK")
Card.Show("Tip", { Text = "Hi", Go = { Text = "Open", Window = "Settings" } })
click("Go")
check("[OK] on welcome back and a tip's [Go] count nothing", #CB == 1, table.concat(CB, ","))
-- Waiting / Busy (ComeBack's opt-in waits on them)
OPEN.Panels = true
Card.Show("Pause", { Next = "x" })
check("a card waits behind a window: Waiting and Busy say so", Card.Waiting() == true and Card.Busy() == true and not Card.IsOpen())
OPEN.Panels = false
Card.Tick()
check("the window closed: the card opens, nothing waits", Card.IsOpen() and Card.Waiting() == false and Card.Busy() == false)
click("OK")

print(("PAUSE_CARD_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("PAUSE_CARD_OFFLINE_OK") end
