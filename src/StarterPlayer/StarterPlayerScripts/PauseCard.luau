-- PauseCard.luau (게임성 개발 1, SPEC A23-79 #1 "멈춤 카드 + Welcome back"): a calm place to stop.
-- Fx "PauseCard" { Next = "<the next goal>", Why = "Chapter" | "Daily" | "War" } - the server sends it to me after it
-- SAVED (a chapter's end, the three daily tasks done, a crown war's end; 게임성 개발 2) - shows "Saved!" / "Next time:
-- <Next>" with [Keep playing] and [OK]: the same size and the same look (stopping is as easy as going on), either one
-- closes it, a tap beside it too. No clock, no countdown, nothing starts by itself, never a purchase button (A23-79).
-- Fx "WelcomeBack" { Next = "<goal>", Zone = "<zone id>"? } - the first spawn after 6 h away - shows "Welcome back!" /
-- "Next: <Next>" with [Go] (the existing Travel channel to Zone; the server checks level, combat, stars) and [OK].
-- A card waits while the screen is busy (a window, the intro, a picker, the map, a reward popup, a confirm box, the
-- first steps before [Claim], knocked out, hurt in the last HurtCalm s) and is dropped after WaitMax s (a stale card
-- is worse than none); one card at a time, a newer one waits for the open one. Presentation only.
-- Public API: PauseCard.Init(C), PauseCard.Start(), PauseCard.OnFx(kind, data), PauseCard.Show(kind, data) -> bool
-- (kind "Pause" | "Back" | "Tip": queue a card), PauseCard.Tick() (opens a waiting card when the screen is free; the offline
-- test drives it), PauseCard.IsOpen(), PauseCard.Build(parent, info) -> the card (이미지 개발 may restyle it: info =
-- { Title, Body, Buttons = { { Id, Text } }, OnButton = fn(id) }), PauseCard.Shown (Util.Signal: kind, button, why;
-- button = "Keep" | "OK" | "Go" | "Backdrop") for the beta metrics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local PauseCard = {}
local C = nil
local TAG = "PauseCard"

local T = {
	Fx = { Pause = "PauseCard", Back = "WelcomeBack" }, -- the server's Fx kinds (plan doc ab338a20; 게임성 개발 2 decides)
	Remote = "Travel", -- [Go]
	WaitMax = 90, -- s a card may wait for a free screen
	HurtCalm = 5, -- s after losing health: no card in the middle of a fight
	Poll = 0.5,
	NextMax = 60, -- characters of the goal shown
	TipMax = 120, -- characters of a tip's words
	ZoneMax = 40,
	Busy = { "Intro", "FactionPicker", "ClassPicker", "WorldMap", "PlayerListUI" }, -- client modules with IsOpen()
	BusyGui = { "RewardPopup", "ConfirmDialog" }, -- UIKit.Gui children: something else is talking
	Gui = "PauseCard",
	Z = 95, -- under UIKit.Confirm (100)
	-- game text: English only (A23-48), short and easy
	Text = {
		PauseTitle = "Saved!",
		PauseNext = "Next time: %s",
		PausePlain = "Everything is saved.",
		Keep = "Keep playing",
		OK = "OK",
		BackTitle = "Welcome back!",
		BackNext = "Next: %s",
		BackPlain = "Good to see you again!",
		Go = "Go",
		TipTitle = "Tip",
	},
}
local S = { Pending = nil, Card = nil, HurtAt = -math.huge, LastPoll = 0, Health = nil }

PauseCard.Shown = Util.Signal.new()

-- the server's goal line, cleaned: no rich-text brackets, one line, trimmed, at most NextMax characters
local function clean(text, max)
	if type(text) ~= "string" then return nil end
	local s = string.gsub(string.gsub(text, "[<>]", ""), "%s+", " ")
	s = string.gsub(string.gsub(s, "^ ", ""), " $", "")
	if s == "" then return nil end
	local n = utf8.len(s)
	if n and n > max then
		s = string.sub(s, 1, utf8.offset(s, max + 1) - 1) .. "…"
	end
	return s
end

local function isOpen(m)
	if type(m) ~= "table" or type(m.IsOpen) ~= "function" then return false end
	local ok, open = pcall(m.IsOpen)
	return ok and open == true
end

-- true while a card would talk over something else
local function busy()
	if not LocalPlayer or LocalPlayer:GetAttribute("DataLoaded") ~= true then return true end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	if os.clock() - S.HurtAt < T.HurtCalm then return true end
	local kit = C and C.UIKit
	if type(kit) == "table" then
		if type(kit.ShouldHoldBanners) == "function" then
			local ok, hold = pcall(kit.ShouldHoldBanners)
			if ok and hold then return true end
		end
		if kit.Gui then
			for _, name in T.BusyGui do
				if kit.Gui:FindFirstChild(name) then return true end
			end
		end
	end
	if isOpen(C and C.Panels) then return true end
	for _, name in T.Busy do
		if isOpen(C and C[name]) then return true end
	end
	return false
end

function PauseCard.IsOpen()
	return S.Card ~= nil and S.Card.Parent ~= nil
end

-- the card: a dim backdrop (a tap = "Backdrop"), the DialogBox plate (UIKit.Confirm's look), title, body, buttons of one
-- size and one look
function PauseCard.Build(parent, info)
	local kit = C and C.UIKit
	if type(kit) ~= "table" or type(info) ~= "table" then return nil end
	local theme = kit.Theme or {}
	local function pick(id)
		if type(info.OnButton) == "function" then info.OnButton(id) end
	end
	local overlay = kit.Create("TextButton", {
		Name = T.Gui,
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(3, 3),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = T.Z,
	})
	overlay.Activated:Connect(function() pick("Backdrop") end)
	local box, boxArt = kit.ArtFrame("DialogBox", {
		Name = "Box",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { BackgroundColor3 = theme.Bg, BackgroundTransparency = 0.05, CornerRadius = UDim.new(0, 16), StrokeColor = theme.Gold,
		StrokeThickness = 2, StrokeTransparency = 0.2 }, {
		kit.Create("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingBottom = UDim.new(0, 22),
			PaddingLeft = UDim.new(0, 26),
			PaddingRight = UDim.new(0, 26),
		}),
		kit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})
	box.Parent = overlay
	-- the "saved" mark when 이미지 개발 has wired its art (Config.UIArt.Parts.IconSaved); no art -> no mark
	if info.Icon and type(kit.ArtImage) == "function" then
		kit.ArtImage(info.Icon, { Name = "Icon", LayoutOrder = 0, Size = UDim2.fromOffset(56, 56), Parent = box })
	end
	kit.StyledLabel({
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 26,
		Text = tostring(info.Title or ""),
		Parent = box,
	}, "Title", boxArt)
	kit.StyledLabel({
		Name = "Body",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 20,
		Text = tostring(info.Body or ""),
		Parent = box,
	}, "Body", boxArt)
	local row = kit.Create("Frame", {
		Name = "Buttons",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = box,
	})
	local buttons = type(info.Buttons) == "table" and info.Buttons or {}
	for i, b in buttons do
		local two = #buttons >= 2
		kit.ArtTextButton("BtnConfirm", {
			Name = tostring(b.Id),
			Text = tostring(b.Text),
			AnchorPoint = two and Vector2.new(i == 1 and 1 or 0, 0) or Vector2.new(0.5, 0),
			Position = two and UDim2.new(0.5, i == 1 and -8 or 8, 0, 2) or UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(180, 52),
			Color = theme.Good,
			TextColor = Color3.fromRGB(30, 25, 10),
			TextSize = 20,
			Parent = row,
		}, function() pick(b.Id) end)
		if i >= 2 then break end
	end
	if parent then overlay.Parent = parent end
	return overlay
end

-- a tip's [Go]: that window (Panels; e.g. Settings with { Tab = "Keys" })
local function openWindow(id, arg)
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, id, arg))
end

-- [Go]: the server's own travel (it says why when it refuses)
local function travel(zone)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.Remote)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	return (pcall(remote.FireServer, remote, zone))
end

local function open(card)
	local kit = C and C.UIKit
	if type(kit) ~= "table" or not kit.Gui then return false end
	local closed = false
	local info = {
		Title = card.Title,
		Body = card.Body,
		Icon = card.Kind == "Pause" and "IconSaved" or nil,
		Buttons = card.Buttons,
	}
	info.OnButton = function(id)
		if closed then return end
		closed = true
		if S.Card then
			pcall(function() S.Card:Destroy() end)
			S.Card = nil
		end
		if id == "Go" and card.Zone then travel(card.Zone) end
		if id == "Go" and card.Window then openWindow(card.Window, card.WindowArg) end
		PauseCard.Shown:Fire(card.Kind, id, card.Why)
		task.defer(PauseCard.Tick) -- a card that waited for this one
	end
	local ok, built = pcall(PauseCard.Build, kit.Gui, info)
	if not ok or not built then
		Util.Warn(TAG, "card failed: " .. tostring(built))
		return false
	end
	S.Card = built
	return true
end

-- opens the waiting card when the screen is free; drops it after WaitMax
function PauseCard.Tick()
	local card = S.Pending
	if not card or PauseCard.IsOpen() then return end
	if os.clock() - card.At > T.WaitMax then
		S.Pending = nil
		return
	end
	if busy() then return end
	S.Pending = nil
	open(card)
end

-- queue a card ("Pause" | "Back"); false when the data is not usable
function PauseCard.Show(kind, data)
	if type(data) ~= "table" then data = {} end
	local nextGoal = clean(data.Next, T.NextMax)
	local card = { Kind = kind, At = os.clock(), Why = type(data.Why) == "string" and data.Why or nil }
	if kind == "Pause" then
		card.Title = T.Text.PauseTitle
		card.Body = nextGoal and string.format(T.Text.PauseNext, nextGoal) or T.Text.PausePlain
		card.Buttons = { { Id = "Keep", Text = T.Text.Keep }, { Id = "OK", Text = T.Text.OK } }
	elseif kind == "Back" then
		card.Title = T.Text.BackTitle
		card.Body = nextGoal and string.format(T.Text.BackNext, nextGoal) or T.Text.BackPlain
		local zone = type(data.Zone) == "string" and #data.Zone > 0 and #data.Zone <= T.ZoneMax and data.Zone or nil
		card.Zone = zone
		card.Buttons = zone and { { Id = "Go", Text = T.Text.Go }, { Id = "OK", Text = T.Text.OK } }
			or { { Id = "OK", Text = T.Text.OK } }
	elseif kind == "Tip" then
		-- A23-81: a one-time tip from a client module ({ Title?, Text, Go = { Text, Window, Arg? } }): [Go] opens that
		-- window (e.g. Settings on its Keys tab), [OK] closes; it waits for a calm screen like every card
		local text = clean(data.Text, T.TipMax)
		if not text then return false end
		card.Title = clean(data.Title, T.NextMax) or T.Text.TipTitle
		card.Body = text
		local go = type(data.Go) == "table" and type(data.Go.Window) == "string" and data.Go or nil
		card.Window = go and go.Window or nil
		card.WindowArg = go and go.Arg or nil
		card.Buttons = go and { { Id = "Go", Text = clean(go.Text, T.NextMax) or T.Text.Go }, { Id = "OK", Text = T.Text.OK } }
			or { { Id = "OK", Text = T.Text.OK } }
	else
		return false
	end
	S.Pending = card -- the newest waiting card wins
	PauseCard.Tick()
	return true
end

function PauseCard.OnFx(kind, data)
	if type(data) == "table" and data.UserId ~= nil and LocalPlayer and data.UserId ~= LocalPlayer.UserId then return end
	if kind == T.Fx.Pause then
		PauseCard.Show("Pause", data)
	elseif kind == T.Fx.Back then
		PauseCard.Show("Back", data)
	end
end

-- "hurt in the last HurtCalm s": the humanoid's health going down
local function watchHealth(char)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not hum then return end
	S.Health = hum.Health
	hum.HealthChanged:Connect(function(h)
		if S.Health and h < S.Health then S.HurtAt = os.clock() end
		S.Health = h
	end)
end

function PauseCard.Init(registry)
	C = registry
end

function PauseCard.Start()
	if not LocalPlayer then return end
	LocalPlayer.CharacterAdded:Connect(function(char) task.spawn(watchHealth, char) end)
	if LocalPlayer.Character then task.spawn(watchHealth, LocalPlayer.Character) end
	RunService.Heartbeat:Connect(function()
		if not S.Pending or os.clock() - S.LastPoll < T.Poll then return end
		S.LastPoll = os.clock()
		local ok, err = pcall(PauseCard.Tick)
		if not ok then Util.Warn(TAG, "tick failed: " .. tostring(err)) end
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
				pcall(PauseCard.OnFx, kind, data)
			end)
		end)
		if not ok then Util.Warn(TAG, "Fx hookup failed: " .. tostring(err)) end
	end)
end

return PauseCard
