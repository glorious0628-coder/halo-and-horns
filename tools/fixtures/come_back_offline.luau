-- Offline checks for ComeBack.luau (SPEC A23-79, 게임성 개발 3's contract: c->s "ClientMetric", the notification opt-in
-- moment, the My Way line) with the real Config.luau (Config.Analytics.ClientMetrics / InviteSources / PassIds,
-- Config.RateLimits.ClientMetric, Config.Notify). The runner (tools/test_come_back.py) prepends CONFIG_SOURCE and
-- COMEBACK_SOURCE. Roblox is replaced by small doubles: Players.LocalPlayer (attributes + their changed signals, a
-- Humanoid with Died), the Remotes folder (ClientMetric recording FireServer), ExperienceNotificationService
-- (CanPromptOptInAsync / PromptOptIn / OptInPromptClosed), MarketplaceService's purchase-finished signals, the Fx remote,
-- a PauseCard double (IsOpen / Waiting / Busy), UIKit.Toast. os.clock is NOW; task.wait moves it (and runs HOOK).
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function signal()
	local s = { Fns = {} }
	function s:Connect(f) table.insert(self.Fns, f) return { Disconnect = function() local i = table.find(self.Fns, f) if i then table.remove(self.Fns, i) end end } end
	function s:Fire(...) for _, f in table.clone(self.Fns) do f(...) end end
	return s
end

local NOW = 1000
local UIS = nil -- set before the env below is used (UserInputService double, Perf device)
local HOOK = nil -- runs on every task.wait (the world moving on while the client waits)
local cfgEnv = setmetatable({
	game = { GetService = function() return setmetatable({}, { __index = function() return function() return nil end end }) end },
	Vector3 = ctor("Vector3"), Vector2 = ctor("Vector2"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	Color3 = { new = function(...) return { ... } end, fromRGB = function(...) return { ... } end, fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum, Instance = { new = function() return {} end },
	typeof = function(v) return type(v) end, warn = function() end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, cfgEnv)
local Config = cfn()

-- the player
local ATTR = { PlaytimeSeconds = 700 }
local ATTR_SIG = {}
local function attrSignal(n) ATTR_SIG[n] = ATTR_SIG[n] or signal() return ATTR_SIG[n] end
local HUM = { Health = 100, Died = signal() }
function HUM:IsA(c) return c == "Humanoid" end
local CHAR = { FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return HUM end return nil end,
	WaitForChild = function() return HUM end }
local LP = { UserId = 7, Character = CHAR, CharacterAdded = signal() }
function LP:GetAttribute(k) return ATTR[k] end
function LP:GetAttributeChangedSignal(k) return attrSignal(k) end
local function setAttr(k, v) ATTR[k] = v attrSignal(k):Fire() end

-- the remotes
local SENT = {}
local REMOTE = {}
function REMOTE:IsA(c) return c == "RemoteEvent" end
function REMOTE:FireServer(...) table.insert(SENT, table.pack(...)) end
local REMOTES = { Items = { ClientMetric = REMOTE } }
function REMOTES:FindFirstChild(n) return self.Items[n] end
local HAS_REMOTES = true
local FX = signal()
local function lastSent()
	local s = SENT[#SENT]
	if not s then return "none" end
	return tostring(s[1]) .. (s.n >= 2 and (":" .. tostring(s[2])) or "")
end

-- Roblox's notification opt-in
local ENS = { Can = true, CanError = false, Prompts = 0, CloseOnPrompt = true, OptInPromptClosed = signal() }
function ENS:CanPromptOptInAsync()
	if self.CanError then error("CanPromptOptInAsync failed") end
	return self.Can
end
function ENS:PromptOptIn()
	self.Prompts += 1
	self.PromptAt = NOW
	if self.CloseOnPrompt then self.OptInPromptClosed:Fire() end
end
local MPS = { PromptGamePassPurchaseFinished = signal(), PromptProductPurchaseFinished = signal() }

local TOASTS = {}
local PC = { Open = false, Wait = false, Busy = false }
local C = {
	UIKit = { Toast = function(text, kind, secs) table.insert(TOASTS, { Text = text, Kind = kind, Secs = secs }) end },
	PauseCard = { IsOpen = function() return PC.Open end, Waiting = function() return PC.Wait end, Busy = function() return PC.Busy end },
}

local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "MarketplaceService" then return MPS end
		if n == "ExperienceNotificationService" then return ENS end
		if n == "UserInputService" then return UIS end
		if n == "Stats" then return { GetTotalMemoryUsageMb = function() return 812.7 end } end
		if n == "ReplicatedStorage" then
			return {
				WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end,
				FindFirstChild = function(_, n2) if n2 == "Remotes" and HAS_REMOTES then return REMOTES end return nil end,
			}
		end
		return {}
	end },
	os = { clock = function() return NOW end, time = os.time },
	workspace = { CurrentCamera = { ViewportSize = { X = 844, Y = 390 } } },
	UserSettings = function() return { GameSettings = { SavedQualityLevel = { Value = 5 } } } end,
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	task = {
		spawn = function(f, ...) f(...) end,
		defer = function(f, ...) f(...) end,
		wait = function(sec) NOW += (sec or 0.03) if HOOK then HOOK() end return sec end,
	},
	require = function(m)
		if m.__module == "Config" then return Config end
		if m.__module == "Net" then return { Get = function(n) if n == "Fx" then return { OnClientEvent = FX } end return {} end } end
		return { Signal = { new = signal }, Warn = function() end }
	end,
}, { __index = getfenv() })

UIS = { TouchEnabled = true, KeyboardEnabled = false, GamepadEnabled = false, WindowFocused = signal(), WindowFocusReleased = signal() }
local function UIS_FOCUS(on)
	if on then UIS.WindowFocused:Fire() else UIS.WindowFocusReleased:Fire() end
end

local function load()
	local fn = assert(loadstring(COMEBACK_SOURCE, "=ComeBack"))
	setfenv(fn, env)
	local m = fn()
	m.Init(C)
	m.Start()
	return m
end

-- 1) ClientMetric: the server's argument rules, one call per id per Config.RateLimits.ClientMetric s
ATTR.MyWay = nil
local CB = load()
check("ShopOpen goes out with no argument", CB.Metric("ShopOpen") == true and SENT[1] and SENT[1].n == 1 and SENT[1][1] == "ShopOpen",
	lastSent())
check("the same id again at once: dropped (Config.RateLimits.ClientMetric)", CB.Metric("ShopOpen") == false and #SENT == 1)
NOW += 0.6
check("... and sent after the gap", CB.Metric("ShopOpen") == true and #SENT == 2)
check("'None' takes no argument", CB.Metric("WelcomeBackGo", "x") == false and #SENT == 2)
check("InviteSent 3 friends", CB.Metric("InviteSent", 3) == true and lastSent() == "InviteSent:3", lastSent())
NOW += 1
check("InviteSent 0 / 51 / 2.5 / '3' are refused", not CB.Metric("InviteSent", 0) and not CB.Metric("InviteSent", 51)
	and not CB.Metric("InviteSent", 2.5) and not CB.Metric("InviteSent", "3") and #SENT == 3, lastSent())
check("InviteSeen from the menu", CB.Metric("InviteSeen", "Menu") == true and lastSent() == "InviteSeen:Menu", lastSent())
NOW += 1
check("InviteSeen from a place not in Config.Analytics.InviteSources is refused", CB.Metric("InviteSeen", "Chat") == false, lastSent())
check("PassView of a pass id", CB.Metric("PassView", "VIP") == true and lastSent() == "PassView:VIP", lastSent())
NOW += 1
check("PassView of something that is no pass is refused", CB.Metric("PassView", "Robux") == false, lastSent())
check("OptIn 'shown' goes, 'maybe' is refused", CB.Metric("OptIn", "maybe") == false and CB.Metric("OptIn", "shown") == true
	and lastSent() == "OptIn:shown", lastSent())
check("an unknown id / no id is refused", CB.Metric("Nope") == false and CB.Metric(nil) == false)
HAS_REMOTES = false
NOW += 1
check("no remote yet: false, no error", CB.Metric("ShopOpen") == false)
HAS_REMOTES = true

-- 2) the opt-in moment
local function fresh(playtime)
	SENT, TOASTS = {}, {}
	-- one live module at a time: the older ones stop listening
	FX.Fns, HUM.Died.Fns, LP.CharacterAdded.Fns = {}, {}, {}
	MPS.PromptGamePassPurchaseFinished.Fns, MPS.PromptProductPurchaseFinished.Fns = {}, {}
	table.clear(ATTR_SIG)
	ENS.Prompts, ENS.Can, ENS.CanError, ENS.CloseOnPrompt = 0, true, false, true
	PC.Open, PC.Wait, PC.Busy = false, false, false
	HUM.Health = 100
	HOOK = nil
	ATTR.PlaytimeSeconds = playtime or 700
	NOW += 1000
	return load()
end
CB = fresh(100)
check("before 10 minutes of play: no moment", CB.OptIn("Daily") == false and ENS.Prompts == 0)
ATTR.PlaytimeSeconds = 700
check("after 10 minutes: Roblox's opt-in window, then 'shown' once it closed", CB.OptIn("Daily") == true and ENS.Prompts == 1
	and lastSent() == "OptIn:shown", lastSent())
check("once a session: a second moment asks nothing", CB.OptIn("Diary") == false and ENS.Prompts == 1)

CB = fresh()
ENS.Can = false
check("Roblox says it cannot ask (under 13, decided, its pause): 'cannot', no window", CB.OptIn("Daily") == true and ENS.Prompts == 0
	and lastSent() == "OptIn:cannot", lastSent())

CB = fresh()
ENS.CanError = true
check("CanPromptOptInAsync errors: nothing sent", CB.OptIn("Daily") == true and ENS.Prompts == 0 and #SENT == 0, lastSent())

CB = fresh()
ENS.CloseOnPrompt = false
check("a window that never closes: no 'shown'", CB.OptIn("Daily") == true and ENS.Prompts == 1 and #SENT == 0, lastSent())

CB = fresh()
HUM.Died:Fire()
check("right after a KO: no moment", CB.OptIn("Daily") == false and ENS.Prompts == 0)
NOW += 61
check("61 s after the KO: the moment comes", CB.OptIn("Daily") == true and ENS.Prompts == 1)

CB = fresh()
HUM.Health = 0
check("knocked out (before any Died was seen): no moment", CB.OptIn("Daily") == false and ENS.Prompts == 0)

CB = fresh()
FX:Fire("Enhance", { Success = false })
check("right after a failed scroll: no moment", CB.OptIn("Daily") == false)
NOW += 61
FX:Fire("Enhance", { Success = true })
check("a scroll that worked does not block it", CB.OptIn("Daily") == true and ENS.Prompts == 1)

CB = fresh()
MPS.PromptGamePassPurchaseFinished:Fire(LP, 1, false)
check("right after a purchase window: no moment", CB.OptIn("Daily") == false)
CB = fresh()
CB.Metric("PurchasePrompt", "XP2")
check("right after a PurchasePrompt: no moment", CB.OptIn("Daily") == false)
CB = fresh()
MPS.PromptGamePassPurchaseFinished:Fire({ UserId = 99 }, 1, false)
check("someone else's purchase window does not block it", CB.OptIn("Daily") == true)

CB = fresh()
PC.Open = true
local t0 = NOW
HOOK = function() if NOW - t0 >= 5 then PC.Open = false end end
check("a pause card is open: the window waits for it", CB.OptIn("Daily") == true and ENS.Prompts == 1 and ENS.PromptAt - t0 >= 5,
	ENS.PromptAt and (ENS.PromptAt - t0))
CB = fresh()
PC.Busy = true
t0 = NOW
HOOK = function() if NOW - t0 >= 120 then PC.Busy = false end end
check("a screen busy for 2 minutes: the stale moment is dropped (90 s)", CB.OptIn("Daily") == true and ENS.Prompts == 0)
CB = fresh()
PC.Wait = true
t0 = NOW
HOOK = function()
	if NOW - t0 >= 2 and NOW - t0 < 2.6 then HUM.Health = 0 HUM.Died:Fire() end
	if NOW - t0 >= 3 then PC.Wait = false HUM.Health = 100 end
end
check("a KO while it waits: it waits out the calm minute too", CB.OptIn("Daily") == true and ENS.Prompts == 1 and ENS.PromptAt - t0 >= 62,
	ENS.PromptAt and (ENS.PromptAt - t0))

CB = fresh()
FX:Fire("OptInMoment", { Why = "Diary" })
check("Fx OptInMoment (after the first diary page) asks", ENS.Prompts == 1 and lastSent() == "OptIn:shown", lastSent())

-- 3) My Way: the first value is quiet, a new name gets a 2 s line
ATTR.MyWay = nil
CB = fresh()
setAttr("MyWay", "")
check("the join value is quiet", #TOASTS == 0)
setAttr("MyWay", "True Knight")
check("A23-191: a new name says nothing", #TOASTS == 0, TOASTS[1] and TOASTS[1].Text)
setAttr("MyWay", "True Knight")
check("the same name again: quiet", #TOASTS == 0)
setAttr("MyWay", "")
check("no name (back to too few picks): quiet", #TOASTS == 0)
setAttr("MyWay", "Rebel Angel")
check("another name: quiet too", #TOASTS == 0, TOASTS[1] and TOASTS[1].Text)
ATTR.MyWay = "Proud Rascal"
CB = fresh()
check("a name already there at the start is quiet", #TOASTS == 0)
setAttr("MyWay", "Balance Walker")
check("... and its change is quiet too", #TOASTS == 0, TOASTS[1] and TOASTS[1].Text)
ATTR.MyWay = nil
CB = fresh()
setAttr("MyWay", "Soft-Hearted Devil")
check("a name as the first value (the join) is quiet", #TOASTS == 0)

-- 빛 마을 점검 #32 (2026-10-10): the phone frame / memory sample (docs/design/phone_perf_server_2026-10-09.md)
CB = fresh()
local good = { D = "Phone", F = 42, W = 18, M = 812, Q = 5 }
check("Perf: a good sample passes the server's rule", CB.ArgOk("Perf", good) == true)
local function with(k, v) local t = table.clone(good) t[k] = v return t end
check("Perf: a missing / extra key, W > F, an unknown device, a fraction, too much memory, Q 11 are refused",
	not CB.ArgOk("Perf", with("Q", nil)) and not CB.ArgOk("Perf", with("X", 1)) and not CB.ArgOk("Perf", with("W", 43))
	and not CB.ArgOk("Perf", with("D", "Fridge")) and not CB.ArgOk("Perf", with("F", 41.5))
	and not CB.ArgOk("Perf", with("M", 20000)) and not CB.ArgOk("Perf", with("Q", 11)) and not CB.ArgOk("Perf", "42"))
check("Perf device: touch + short side 390 = Phone, 700 = Tablet, a keyboard = Desktop, a gamepad only = Console",
	CB.PerfDevice(true, false, false, 390) == "Phone" and CB.PerfDevice(true, false, false, 700) == "Tablet"
	and CB.PerfDevice(true, true, false, 390) == "Desktop" and CB.PerfDevice(false, false, true, 0) == "Console")
check("Perf pack: under 60 focused s nothing", CB.PerfPack("Phone", 1770, 59, {}, 800, 5) == nil)
local pk = CB.PerfPack("Phone", 3600, 60, { 58, 42.6, 61 }, 812.7, 5)
check("Perf pack: F = frames / s, W = the lowest full second (whole), M floored, Q kept",
	pk and pk.F == 60 and pk.W == 42 and pk.M == 812 and pk.Q == 5 and pk.D == "Phone", pk and (pk.F .. "/" .. pk.W) or "nil")
SENT = {}
ATTR.DataLoaded = nil
for _ = 1, 30 * 130 do NOW += 1 / 30 CB.PerfFrame(1 / 30) end
check("Perf: nothing before my data loads", #SENT == 0, #SENT)
ATTR.DataLoaded = true
for _ = 1, 30 * 121 do NOW += 1 / 30 CB.PerfFrame(1 / 30) end
local last = SENT[#SENT]
check("Perf: every 120 s one sample of the window (30 fps phone, the doubles' memory and quality)", #SENT == 1 and last[1] == "Perf"
	and type(last[2]) == "table" and last[2].D == "Phone" and last[2].F == 30 and last[2].W <= 30 and last[2].M == 812 and last[2].Q == 5,
	last and last[2] and (tostring(last[2].F) .. " " .. tostring(last[2].D)) or "nil")
SENT = {}
for i = 1, 30 * 121 do
	NOW += 1 / 30
	if i == 30 * 10 then UIS_FOCUS(false) end
	CB.PerfFrame(1 / 30)
end
UIS_FOCUS(true)
check("Perf: a window mostly out of focus (under 60 s played) sends nothing", #SENT == 0, #SENT)
SENT = {}
for i = 1, 121 do NOW += 1 CB.PerfFrame(i % 2 == 0 and 6 or 1 / 30) end
check("Perf: gaps over 5 s (the app away) never count as play", #SENT == 0, #SENT)
-- 검수 10/10: a real freeze of 1..5 s is play - one low second
SENT = {}
for i = 1, 30 * 121 do
	NOW += 1 / 30
	CB.PerfFrame(i == 30 * 50 and 3 or 1 / 30)
end
local frz = SENT[#SENT]
check("Perf: a 3 s freeze shows as the window's lowest second (W 0), the average stays near 30",
	frz and frz[2] and frz[2].W == 0 and frz[2].F >= 25, frz and frz[2] and (tostring(frz[2].F) .. "/" .. tostring(frz[2].W)) or "nil")
ATTR.DataLoaded = nil

print(("COME_BACK_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("COME_BACK_OFFLINE_OK") end
