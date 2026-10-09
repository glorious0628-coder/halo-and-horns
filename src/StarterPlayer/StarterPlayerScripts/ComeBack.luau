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
--   My Way (#2): the MyWay attribute (ReturnService: the name from my own story picks, "" = none yet) changing after its
--   first value -> one 2 s line. No judging, no stats.
-- Presentation + the prompt only; the server owns every rule and record.
-- Public API: ComeBack.Init(C), ComeBack.Start(), ComeBack.Metric(id, arg?), ComeBack.ArgOk(rule, arg),
-- ComeBack.OptIn(why), ComeBack.Calm() -> bool, ComeBack.OnFx(kind, data), ComeBack.OnMyWay(value) -> the line shown or nil,
-- ComeBack.Bought() (a purchase window was used: the calm clock; Passes / ShopUI may call it too).
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
	-- game text: English only (A23-48), short and easy
	Text = { MyWay = "Your way: %s" },
}
local S = { SentAt = {}, OptInAsked = false, KOAt = -math.huge, FailAt = -math.huge, BuyAt = -math.huge,
	MyWay = nil, MyWaySeen = false }

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
	if type(rule) == "table" then return type(arg) == "string" and table.find(rule, arg) ~= nil end
	return false
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

function ComeBack.Start()
	if not LocalPlayer then return end
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
