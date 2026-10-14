-- PauseCard.luau (게임성 개발 1, SPEC A23-79 #1 "멈춤 카드 + Welcome back"): a calm place to stop.
-- Fx "PauseCard" { Next = "<the next goal>", Why = "Chapter" | "Daily" | "War" } - the server sends it to me after it
-- SAVED (a chapter's end, the three daily tasks done, a crown war's end; 게임성 개발 2) - shows "Saved!" / "Next time:
-- <Next>" with [Keep playing] and [OK]: the same size and the same look (stopping is as easy as going on), either one
-- closes it, a tap beside it too. No clock, no countdown, nothing starts by itself, never a purchase button (A23-79).
-- 검수 10/11 (A23-130 less text): only a chapter's end shows it (T.PauseWhy); the daily / war cards are dropped, and a
-- dropped card's OptIn still hands the opt-in moment to ComeBack (it waits for a calm screen itself).
-- Fx "WelcomeBack" { Next = "<goal>", Zone = "<zone id>"? } - the first spawn after 6 h away - shows "Welcome back!" /
-- "Next: <Next>" with [Go] (the existing Travel channel to Zone; the server checks level, combat, stars) and [OK].
-- 게임성 개발 3's contract (return_server_2026-10-08.md): the daily card also carries Tomorrow ("New dailies" / "King Diary
-- page N": one more line "Tomorrow: …") and OptIn = true (once the card is closed, the notification opt-in moment:
-- ComeBack.OptIn "Daily"); [Go] on the welcome-back card -> ClientMetric "WelcomeBackGo" (ComeBack.Metric).
-- A card waits while the screen is busy (a window, the intro, a picker, the map, a reward popup, a confirm box, the
-- first steps before [Claim], knocked out, hurt in the last HurtCalm s) and is dropped after WaitMax s (a stale card
-- is worse than none); one card at a time, a newer one waits for the open one. Presentation only.
-- Public API: PauseCard.Init(C), PauseCard.Start(), PauseCard.OnFx(kind, data), PauseCard.Show(kind, data) -> bool
-- (kind "Pause" | "Back" | "Tip": queue a card), PauseCard.Tick() (opens a waiting card when the screen is free; the offline
-- test drives it), PauseCard.IsOpen(), PauseCard.Waiting() (a card waits), PauseCard.Busy() (the screen is talking: the
-- calm-screen rule, also ComeBack's opt-in), PauseCard.Build(parent, info) -> the card (이미지 개발 may restyle it: info =
-- { Title, Body, Buttons = { { Id, Text } }, OnButton = fn(id) }), PauseCard.Shown (Util.Signal: kind, button, why;
-- button = "Keep" | "OK" | "Go" | "Backdrop") for the beta metrics, PauseCard.OpenKind() -> the open card's kind or nil
-- (Audio: "Back" WelcomeBack, "Tip" TipDing, else WindowOpen).
-- A23-167 ② (game dev 2's server, docs/design/comeback_server_2026-10-14.md): Fx "TomorrowGift" { Tomorrow, Today?, Days }
-- -> the "Tomorrow" card: Config.Return.Text.TomorrowTitle / TomorrowLine (the slot a claim tomorrow pays) with that
-- attendance slot's own art (AttendanceUI.SlotIcon); with Today (a claim still open) one more line and [Open] = the
-- attendance window. WelcomeBack's News (the "while you were away" line) is one more line of the welcome-back card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local Config = require(Shared:WaitForChild("Config"))

local LocalPlayer = Players.LocalPlayer

local PauseCard = {}
local C = nil
local TAG = "PauseCard"

local T = {
	Fx = { Pause = "PauseCard", Back = "WelcomeBack", Tomorrow = "TomorrowGift" }, -- the server's Fx kinds (게임성 개발 2)
	Remote = "Travel", -- [Go]
	WaitMax = 90, -- s a card may wait for a free screen
	HurtCalm = 5, -- s after losing health: no card in the middle of a fight
	Poll = 0.5,
	NextMax = 60, -- characters of the goal shown
	TipMax = 120, -- characters of a tip's words (each line)
	TipLines = 2, -- lines of a tip (A23-130: the PvP card = the danger line + one short line)
	PauseWhy = { Chapter = true }, -- the server's whys that get the "Saved!" card (검수 10/11: a chapter's end only)
	TomorrowMax = 40, -- characters of the daily card's tomorrow line
	ZoneMax = 40,
	NewsMax = 80, -- characters of the welcome-back card's "while you were away" line (A23-167)
	SlotMax = 99, -- the highest attendance slot a TomorrowGift may name
	Busy = { "Intro", "FactionPicker", "ClassPicker", "WorldMap", "PlayerListUI" }, -- client modules with IsOpen()
	BusyGui = { "RewardPopup", "ConfirmDialog" }, -- UIKit.Gui children: something else is talking
	Gui = "PauseCard",
	Z = 95, -- under UIKit.Confirm (100)
	-- game text: English only (A23-48), short and easy
	Text = Config.ClientText.PauseCard, -- the words: Config.ClientText.PauseCard (moved 10/14)
}

-- 최종 검수 10/14 (A23-179: Roblox's automatic translation matches whole drawn sentences, so a line with a number or a
-- name stayed English): a sentence with %-slots by its table key (UIKit.Tx -> UIKit.Tr: the localization table by key;
-- English exactly as before); without UIKit (offline tests) string.format; a failed format = the words as they are
local function trx(t, key, ...)
	local f = type(t) == "table" and (t[key .. "En"] or t[key]) or nil
	if type(f) ~= "string" then return nil end
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Tx) == "function" then
		local ok, out = pcall(kit.Tx, t, key, ...)
		if ok and type(out) == "string" then return out end
	end
	local ok, out = pcall(string.format, f, ...)
	return ok and out or f
end
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

-- a tip's words: up to TipLines lines, each cleaned like the goal (empty lines dropped)
local function cleanLines(text, max, lines)
	if type(text) ~= "string" then return nil end
	local out = {}
	for line in string.gmatch(text, "[^\n]+") do
		local s = clean(line, max)
		if s then table.insert(out, s) end
		if #out >= lines then break end
	end
	return #out > 0 and table.concat(out, "\n") or nil
end

-- a whole attendance slot 1..SlotMax, else nil
local function slotOf(v)
	return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= T.SlotMax and v or nil
end

-- A23-167's card words (Config.Return.Text, 게임성 개발 2 / 최종 검수 own them)
local function returnText()
	local r = type(Config) == "table" and type(Config.Return) == "table" and Config.Return.Text or nil
	return type(r) == "table" and r or {}
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

function PauseCard.OpenKind()
	return PauseCard.IsOpen() and S.Kind or nil
end

function PauseCard.Waiting()
	return S.Pending ~= nil
end

function PauseCard.Busy()
	return busy()
end

-- the return parts (ComeBack.luau): a metric / the opt-in moment, never an error here
local function comeBack(fn, ...)
	local cb = C and C.ComeBack
	if type(cb) == "table" and type(cb[fn]) == "function" then pcall(cb[fn], ...) end
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
	local body = kit.StyledLabel({
		Name = "Body",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 20,
		Text = tostring(info.Body or ""),
		Parent = box,
	}, "Body", boxArt)
	if type(kit.BalanceLines) == "function" then kit.BalanceLines(body) end -- 이미지 개발 10/10: no word alone on a line
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

-- the tomorrow card's [Open]: the attendance window (AttendanceUI.Open)
local function openAttendance()
	local att = C and C.AttendanceUI
	if type(att) ~= "table" or type(att.Open) ~= "function" then return false end
	local ok, opened = pcall(att.Open)
	return ok and opened == true
end

-- that attendance slot's art (AttendanceUI.SlotIcon), or nil (the card shows no mark)
local function slotIcon(slot)
	local att = C and C.AttendanceUI
	if type(att) ~= "table" or type(att.SlotIcon) ~= "function" then return nil end
	local ok, key = pcall(att.SlotIcon, slot)
	return ok and type(key) == "string" and key or nil
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
		Icon = card.Kind == "Pause" and "IconSaved" or card.Icon,
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
		if id == "Go" and card.Attend then openAttendance() end
		if id == "Go" and card.Kind == "Back" then comeBack("Metric", "WelcomeBackGo") end
		PauseCard.Shown:Fire(card.Kind, id, card.Why)
		if card.OptIn then task.defer(comeBack, "OptIn", "Daily") end -- after the card, never over it
		task.defer(PauseCard.Tick) -- a card that waited for this one
	end
	local ok, built = pcall(PauseCard.Build, kit.Gui, info)
	if not ok or not built then
		Util.Warn(TAG, "card failed: " .. tostring(built))
		return false
	end
	S.Card = built
	S.Kind = card.Kind
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
		if card.Why and not T.PauseWhy[card.Why] then
			if data.OptIn == true then comeBack("OptIn", card.Why) end -- the server spent the moment on this card
			return false
		end
		card.Title = T.Text.PauseTitle
		card.Body = nextGoal and trx(T.Text, "PauseNext", nextGoal) or T.Text.PausePlain
		local tomorrow = clean(data.Tomorrow, T.TomorrowMax)
		if tomorrow then card.Body ..= "\n" .. trx(T.Text, "PauseTomorrow", tomorrow) end
		card.OptIn = data.OptIn == true
		card.Buttons = { { Id = "Keep", Text = T.Text.Keep }, { Id = "OK", Text = T.Text.OK } }
	elseif kind == "Back" then
		card.Title = T.Text.BackTitle
		card.Body = nextGoal and trx(T.Text, "BackNext", nextGoal) or T.Text.BackPlain
		local news = clean(data.News, T.NewsMax) -- A23-167: the "while you were away" line, only when the server has one
		if news then card.Body ..= "\n" .. news end
		local zone = type(data.Zone) == "string" and #data.Zone > 0 and #data.Zone <= T.ZoneMax and data.Zone or nil
		card.Zone = zone
		card.Buttons = zone and { { Id = "Go", Text = T.Text.Go }, { Id = "OK", Text = T.Text.OK } }
			or { { Id = "OK", Text = T.Text.OK } }
	elseif kind == "Tip" then
		-- A23-81: a one-time tip from a client module ({ Title?, Text, Go = { Text, Window, Arg? } }): [Go] opens that
		-- window (e.g. Settings on its Keys tab), [OK] closes; it waits for a calm screen like every card
		local text = cleanLines(data.Text, T.TipMax, T.TipLines)
		if not text then return false end
		card.Title = clean(data.Title, T.NextMax) or T.Text.TipTitle
		card.Body = text
		local go = type(data.Go) == "table" and type(data.Go.Window) == "string" and data.Go or nil
		card.Window = go and go.Window or nil
		card.WindowArg = go and go.Arg or nil
		card.Buttons = go and { { Id = "Go", Text = clean(go.Text, T.NextMax) or T.Text.Go }, { Id = "OK", Text = T.Text.OK } }
			or { { Id = "OK", Text = T.Text.OK } }
	elseif kind == "Tomorrow" then
		-- A23-167 ②: the gift a claim tomorrow pays (its slot's art); today's still open -> one more line + [Open]
		local words, slot = returnText(), slotOf(data.Tomorrow)
		if not slot or type(words.TomorrowLine) ~= "string" or type(words.TomorrowTitle) ~= "string" then return false end
		card.Title = words.TomorrowTitle
		card.Body = string.format(words.TomorrowLine, slot)
		card.Icon = slotIcon(slot)
		if slotOf(data.Today) and type(words.TodayLine) == "string" then
			card.Body ..= "\n" .. words.TodayLine
			card.Attend = true
			card.Buttons = { { Id = "Go", Text = T.Text.Open }, { Id = "OK", Text = T.Text.OK } }
		else
			card.Buttons = { { Id = "OK", Text = T.Text.OK } }
		end
	else
		return false
	end
	S.Pending = card -- the newest waiting card wins
	PauseCard.Tick()
	return true
end

function PauseCard.OnFx(_kind, _data)
	-- A23-191 (user 10/14 "다 삭제하라고"): no "Saved!" / "Welcome back!" / "Tomorrow" card any more (the server's Fx is
	-- ignored); tips from other modules are gone too (their Show("Tip") calls were removed)
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
	pcall(function() C.UIKit.L10n.Register("PauseCard.T.Text", T.Text) end) -- 10/14: the words' keys "PauseCard.T.Text.<key>" (trx)
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
