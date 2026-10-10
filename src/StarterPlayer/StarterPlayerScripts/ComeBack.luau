-- ComeBack.luau (게임성 개발 1, SPEC A23-79 "다시 오게 만들기"): the client's small parts of 게임성 개발 3's server contract
-- (docs/design/return_server_2026-10-08.md, docs/design/beta_metrics_server_2026-10-08.md).
--   ComeBack.Metric(id, arg?) -> bool: c->s "ClientMetric" for what only the client sees. The same argument rules as the
--   server (Config.Analytics.ClientMetrics: "None" / "Count" 1..50 / "Source" / "Pass" / a list), so a wrong call never
--   leaves the client; one call per id per Config.RateLimits.ClientMetric s (the server drops faster ones anyway).
--   ComeBack.OptIn(why) -> bool: the notification opt-in moment (#5: Fx "OptInMoment" { Why } after the first King Diary
--   page, or the daily pause card's OptIn flag once that card is closed). Once a session, never in the first
--   Config.Notify.MinPlaySeconds of play (PlaytimeSeconds) or within Config.Notify.Calm s of my KO / a failed scroll / a
--   purchase window; it waits for a calm screen (PauseCard.Busy: no card, window, picker or fight) for at most WaitMax s,
--   then ExperienceNotificationService:CanPromptOptInAsync() (Roblox decides 13+, an earlier answer, its own pause) ->
--   PromptOptIn() -> OptInPromptClosed -> ClientMetric("OptIn", "shown"); Roblox said no -> ClientMetric("OptIn",
--   "cannot"). The server keeps the asked list and the "never again" rule.
--   Perf (빛 마을 점검 #32; docs/design/phone_perf_server_2026-10-09.md "개발 1에게"): every Config.Analytics.Perf.Every
--   s after my data loads, ClientMetric("Perf", { D, F, W, M, Q }) for the window just gone - D the device (touch only:
--   Phone when the screen's short side is under T.TabletPx, else Tablet; a keyboard: Desktop; a gamepad only: Console),
--   F its average FPS, W the lowest full second (never above F), M Stats memory MB, Q the saved graphics level (0 =
--   auto). Only frames while the game window had focus count; a frame gap of 1..5 s is a freeze (a low second), a
--   longer one the app away (dropped); under
--   T.PerfActive s of such play in a window -> nothing sent. Nothing on screen changes.
--   My Way (#2): the MyWay attribute (ReturnService: the name from my own story picks, "" = none yet) changing after its
--   first value -> one 2 s line. No judging, no stats.
-- Presentation + the prompt only; the server owns every rule and record.
-- Public API: ComeBack.Init(C), ComeBack.Start(), ComeBack.Metric(id, arg?), ComeBack.ArgOk(rule, arg),
-- ComeBack.OptIn(why), ComeBack.Calm() -> bool, ComeBack.OnFx(kind, data), ComeBack.OnMyWay(value) -> the line shown or nil,
-- ComeBack.Bought() (a purchase window was used: the calm clock; Passes / ShopUI may call it too),
-- ComeBack.PerfDevice(touch, keyboard, gamepad, shortSide) -> D, ComeBack.PerfPack(d, frames, active, seconds, mem, q) -> arg | nil,
-- ComeBack.PerfFrame(dt) (one frame of the Perf window).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local ComeBack = {}
local C = nil
local TAG = "ComeBack"

local T = {
	Remote = "ClientMetric",
	Gap = 0.5, -- s per metric id (Config.RateLimits.ClientMetric)
	WaitMax = 90, -- s the opt-in moment may wait for a calm screen
	Poll = 0.5,
	PromptMax = 300, -- s waiting for Roblox's opt-in window to close
	MyWaySeconds = 2,
	TabletPx = 600, -- a touch screen whose short side is this many px or more is a tablet
	PerfActive = 60, -- s of focused play a Perf window needs (the contract)
	PerfGapCut = 5, -- s: a longer frame gap is the app away (dropped); 1..5 s counts as a freeze (검수 10/10)
	-- game text: English only (A23-48), short and easy
	Text = { MyWay = "Your way: %s" },
}
local S = { SentAt = {}, OptInAsked = false, KOAt = -math.huge, FailAt = -math.huge, BuyAt = -math.huge,
	MyWay = nil, MyWaySeen = false,
	-- the Perf window: frames / active s counted, the current second's frames + time, the full seconds' FPS list
	Perf = { Frames = 0, Active = 0, SecFrames = 0, SecTime = 0, Seconds = {}, Focused = true, Started = 0 } }

local function cfg(name, default)
	local n = Config.Notify
	local v = type(n) == "table" and tonumber(n[name]) or nil
	return v or default
end

-- the server's rule for one argument (TelemetryService argOk)
function ComeBack.ArgOk(rule, arg)
	local A = Config.Analytics or {}
	if rule == "None" then return arg == nil end
	if rule == "Count" then return type(arg) == "number" and arg == math.floor(arg) and arg >= 1 and arg <= 50 end
	if rule == "Source" then return type(arg) == "string" and table.find(A.InviteSources or {}, arg) ~= nil end
	if rule == "Pass" then
		return type(arg) == "string" and #arg <= 32 and (table.find(A.PassIds or {}, arg) ~= nil
			or (type(Config.GamePasses) == "table" and Config.GamePasses[arg] ~= nil)
			or (type(Config.Looks) == "table" and Config.Looks[arg] ~= nil))
	end
	if rule == "Perf" then -- TelemetryService perfOk: exactly D F W M Q, whole numbers in range, W <= F
		if type(arg) ~= "table" then return false end
		local P = A.Perf or {}
		for k in arg do
			if k ~= "D" and k ~= "F" and k ~= "W" and k ~= "M" and k ~= "Q" then return false end
		end
		local function whole(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
		return type(arg.D) == "string" and table.find(A.PerfDevices or {}, arg.D) ~= nil
			and whole(arg.F, 0, tonumber(P.MaxFps) or 240) and whole(arg.W, 0, arg.F)
			and whole(arg.M, 0, tonumber(P.MaxMem) or 16384) and whole(arg.Q, 0, tonumber(P.MaxQuality) or 10)
	end
	if type(rule) == "table" then return type(arg) == "string" and table.find(rule, arg) ~= nil end
	return false
end

-- the Perf device word (pure)
function ComeBack.PerfDevice(touch, keyboard, gamepad, shortSide)
	if keyboard then return "Desktop" end
	if touch then return (tonumber(shortSide) or 0) >= T.TabletPx and "Tablet" or "Phone" end
	if gamepad then return "Console" end
	return "Desktop"
end

-- the Perf argument of one window (pure): frames over active focused s, the full seconds' FPS (lowest = W, never above
-- F), memory MB, quality level; nil under T.PerfActive s
function ComeBack.PerfPack(d, frames, active, seconds, mem, q)
	if type(active) ~= "number" or active < T.PerfActive or type(frames) ~= "number" then return nil end
	local P = (Config.Analytics and Config.Analytics.Perf) or {}
	local f = math.clamp(math.floor(frames / active + 0.5), 0, tonumber(P.MaxFps) or 240)
	local w = f
	for _, v in type(seconds) == "table" and seconds or {} do
		if type(v) == "number" then w = math.min(w, math.max(0, math.floor(v))) end
	end
	return { D = d, F = f, W = math.min(w, f), M = math.clamp(math.floor(tonumber(mem) or 0), 0, tonumber(P.MaxMem) or 16384),
		Q = math.clamp(math.floor(tonumber(q) or 0), 0, tonumber(P.MaxQuality) or 10) }
end

function ComeBack.Metric(id, arg)
	local rules = Config.Analytics and Config.Analytics.ClientMetrics
	local rule = type(rules) == "table" and type(id) == "string" and rules[id] or nil
	if rule == nil or not ComeBack.ArgOk(rule, arg) then return false end
	local gap = tonumber(Config.RateLimits and Config.RateLimits.ClientMetric) or T.Gap
	local now = os.clock()
	if S.SentAt[id] and now - S.SentAt[id] < gap then return false end
	S.SentAt[id] = now
	if id == "PurchasePrompt" then S.BuyAt = now end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.Remote)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	local ok, err
	if arg == nil then
		ok, err = pcall(remote.FireServer, remote, id)
	else
		ok, err = pcall(remote.FireServer, remote, id, arg)
	end
	if not ok then Util.Warn(TAG, "metric " .. id .. " failed: " .. tostring(err)) end
	return ok
end

function ComeBack.Bought()
	S.BuyAt = os.clock()
end

-- no opt-in right after my KO, a failed scroll or a purchase window (Config.Notify.Calm)
function ComeBack.Calm()
	local calm, now = cfg("Calm", 60), os.clock()
	for _, at in { S.KOAt, S.FailAt, S.BuyAt } do
		if now - at < calm then return false end
	end
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- the screen is talking (a pause card open or waiting, a window, a picker, a fight: PauseCard.Busy)
local function screenBusy()
	local pc = C and C.PauseCard
	if type(pc) ~= "table" then return false end
	for _, name in { "IsOpen", "Waiting", "Busy" } do
		if type(pc[name]) == "function" then
			local ok, yes = pcall(pc[name])
			if ok and yes == true then return true end
		end
	end
	return false
end

local function service()
	local ok, ens = pcall(function() return game:GetService("ExperienceNotificationService") end)
	return ok and ens or nil
end

local function prompt()
	local ens = service()
	if not ens then return end
	local okCan, can = pcall(ens.CanPromptOptInAsync, ens)
	if not okCan then
		Util.Warn(TAG, "CanPromptOptInAsync failed: " .. tostring(can))
		return
	end
	if can ~= true then
		ComeBack.Metric("OptIn", "cannot")
		return
	end
	local closed = false
	local conn = ens.OptInPromptClosed:Connect(function() closed = true end)
	local okP, err = pcall(ens.PromptOptIn, ens)
	if not okP then
		conn:Disconnect()
		Util.Warn(TAG, "PromptOptIn failed: " .. tostring(err))
		return
	end
	local t0 = os.clock()
	while not closed and os.clock() - t0 < T.PromptMax do task.wait(T.Poll) end
	conn:Disconnect()
	if closed then ComeBack.Metric("OptIn", "shown") end
end

function ComeBack.OptIn(why)
	if S.OptInAsked or not LocalPlayer then return false end
	local played = tonumber(LocalPlayer:GetAttribute("PlaytimeSeconds")) or 0
	if played < cfg("MinPlaySeconds", 600) or not ComeBack.Calm() then return false end
	S.OptInAsked = true -- one moment a session (the server sends at most one too)
	task.spawn(function()
		local t0 = os.clock()
		repeat
			task.wait(T.Poll)
			if os.clock() - t0 > T.WaitMax then return end -- a stale moment is dropped
		until not screenBusy() and ComeBack.Calm()
		local ok, err = pcall(prompt)
		if not ok then Util.Warn(TAG, "opt-in (" .. tostring(why) .. ") failed: " .. tostring(err)) end
	end)
	return true
end

function ComeBack.OnFx(kind, data)
	if kind == "OptInMoment" then
		ComeBack.OptIn(type(data) == "table" and data.Why or nil)
	elseif kind == "Enhance" and type(data) == "table" and data.Success == false then
		S.FailAt = os.clock()
	end
end

-- MyWay changed: the first value (the join) is quiet; a new name gets its 2 s line
function ComeBack.OnMyWay(value)
	local name = type(value) == "string" and value or ""
	local first = not S.MyWaySeen
	local before = S.MyWay
	S.MyWaySeen, S.MyWay = true, name
	if first or name == "" or name == before then return nil end
	local line = string.format(T.Text.MyWay, name)
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Toast) == "function" then pcall(kit.Toast, line, "good", T.MyWaySeconds) end
	return line
end

local function watchKO(char)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function() S.KOAt = os.clock() end)
end

function ComeBack.Init(registry)
	C = registry
end

-- the window just gone -> ClientMetric "Perf" (when it had T.PerfActive focused s)
local function perfSend()
	local P = S.Perf
	local UIS = game:GetService("UserInputService")
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local mem, q = 0, 0
	pcall(function() mem = game:GetService("Stats"):GetTotalMemoryUsageMb() end)
	pcall(function() q = UserSettings().GameSettings.SavedQualityLevel.Value end)
	local arg = ComeBack.PerfPack(ComeBack.PerfDevice(UIS.TouchEnabled, UIS.KeyboardEnabled, UIS.GamepadEnabled,
		math.min(vp.X, vp.Y)), P.Frames, P.Active, P.Seconds, mem, q)
	if arg then return ComeBack.Metric("Perf", arg) end
	return false
end

-- one frame (RenderStepped dt): the window starts when my data has loaded; frames count only while the game window
-- has focus and never a gap over a second (the app away); every Perf.Every s the window is sent and a new one starts
function ComeBack.PerfFrame(dt)
	local P = S.Perf
	local now = os.clock()
	if LocalPlayer:GetAttribute("DataLoaded") ~= true then
		P.Started = now
		return
	end
	if P.Focused and type(dt) == "number" and dt > 0 and dt <= T.PerfGapCut then
		P.Frames += 1
		P.Active += dt
		if dt > 1 then -- 검수 10/10: a stall of 1..5 s is a real freeze: its own low second (1 / dt FPS)
			table.insert(P.Seconds, 1 / dt)
		else
			P.SecFrames += 1
			P.SecTime += dt
			if P.SecTime >= 1 then
				table.insert(P.Seconds, P.SecFrames / P.SecTime)
				P.SecFrames, P.SecTime = 0, 0
			end
		end
	end
	local every = tonumber(Config.Analytics and Config.Analytics.Perf and Config.Analytics.Perf.Every) or 120
	if now - P.Started >= every then
		perfSend()
		P.Frames, P.Active, P.SecFrames, P.SecTime, P.Seconds, P.Started = 0, 0, 0, 0, {}, now
	end
end

function ComeBack.Start()
	if not LocalPlayer then return end
	S.Perf.Started = os.clock()
	pcall(function()
		local UIS = game:GetService("UserInputService")
		UIS.WindowFocused:Connect(function() S.Perf.Focused = true end)
		UIS.WindowFocusReleased:Connect(function() S.Perf.Focused = false end)
		game:GetService("RunService").RenderStepped:Connect(function(dt) pcall(ComeBack.PerfFrame, dt) end)
	end)
	LocalPlayer.CharacterAdded:Connect(function(char) task.spawn(watchKO, char) end)
	if LocalPlayer.Character then task.spawn(watchKO, LocalPlayer.Character) end
	if LocalPlayer:GetAttribute("MyWay") ~= nil then ComeBack.OnMyWay(LocalPlayer:GetAttribute("MyWay")) end
	LocalPlayer:GetAttributeChangedSignal("MyWay"):Connect(function()
		pcall(ComeBack.OnMyWay, LocalPlayer:GetAttribute("MyWay"))
	end)
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player)
			if player == LocalPlayer then ComeBack.Bought() end
		end)
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
			if userId == LocalPlayer.UserId then ComeBack.Bought() end
		end)
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
				pcall(ComeBack.OnFx, kind, data)
			end)
		end)
		if not ok then Util.Warn(TAG, "Fx hookup failed: " .. tostring(err)) end
	end)
end

return ComeBack
