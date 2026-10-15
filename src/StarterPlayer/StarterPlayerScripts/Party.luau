-- Party.luau : SPEC A23-201 the party, the client minimum (api party2, 2026-10-15; server PartyService). Display + asks
-- only; the server decides everything (who may invite, room, range, the 30 s card).
--   * Party frames at the left: one row per OTHER member (side colour strip, name, HP bar from that player's Humanoid),
--     a small [Leave] under them. Hidden when I am in no party.
--   * The invite card: the inviter's name + [Join] / [Not now] (no text paragraph; A23-191). It closes when the server
--     says InviteGone, when I answer, or after its TTL.
--   * Party.Invite(player) (PlayerListUI's [Party] row button) -> PartyAction "Invite"; Party.Leave() -> "Leave".
--   * Party.Marked(player) -> true for my party members and Roblox friends (MiniMap's bigger dots; friends asked once per
--     player in the background, never yielding the caller).
-- Words: Config.ClientText.Party only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local Party = {}

local C = nil -- client registry
local TAG = "Party"
local TXT = Config.ClientText.Party or {}
local L = { -- layout, logical MainGui units
	X = 12, Y = 0.36, W = 180, RowH = 34, BarH = 6, Strip = 5, Gap = 4, LeaveW = 72, LeaveH = 26,
	CardW = 240, CardH = 86, CardY = 0.22, Z = 40, Refresh = 0.25, MaxRows = 3, NameSize = 15, BtnSize = 15,
}
local S = { Id = 0, Leader = 0, Members = {}, Card = nil, Friends = {}, WarnAt = -math.huge, Started = false }
local ui = { rows = {} }

local function warnThrottled(msg)
	local now = os.clock()
	if now - S.WarnAt < 10 then return end
	S.WarnAt = now
	Util.Warn(TAG, msg)
end

local function kit()
	return C and C.UIKit
end

local function themeColor(key, fallback)
	local k = kit()
	local theme = k and k.Theme
	return (theme and typeof(theme[key]) == "Color3") and theme[key] or fallback
end

local function sideColor(faction)
	if faction == "Halo" or faction == "Horns" or faction == "Neutral" then
		return themeColor(faction, Color3.fromRGB(200, 200, 210))
	end
	return themeColor("SubText", Color3.fromRGB(200, 200, 210))
end

-- the remote without waiting (a missing remote = nothing sent)
local function remote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local r = folder and folder:FindFirstChild(name)
	return (r and r:IsA("RemoteEvent")) and r or nil
end

local function send(op, arg)
	local r = remote("PartyAction")
	if not r then return false end
	local ok, err
	if arg == nil then ok, err = pcall(r.FireServer, r, op) else ok, err = pcall(r.FireServer, r, op, arg) end
	if not ok then warnThrottled("PartyAction: " .. tostring(err)) end
	return ok
end

------------------------------------------------------------------ public asks
function Party.Invite(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player == LocalPlayer or player.Parent ~= Players then return false end
	return send("Invite", player.UserId)
end

function Party.Leave()
	if S.Id == 0 then return false end
	return send("Leave")
end

function Party.InParty()
	return S.Id ~= 0
end

function Party.MemberIds()
	return table.clone(S.Members)
end

function Party.Marked(player)
	if typeof(player) ~= "Instance" or player == LocalPlayer then return false end
	local id = player.UserId
	if S.Id ~= 0 and table.find(S.Members, id) then return true end
	local f = S.Friends[id]
	if f == nil then
		S.Friends[id] = false -- asked once; the answer lands later
		task.spawn(function()
			local ok, res = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, id)
			S.Friends[id] = ok and res == true
		end)
		return false
	end
	return f == true
end

------------------------------------------------------------------ the frames
local function build()
	if ui.root and ui.root.Parent then return true end
	local k = kit()
	local gui = k and k.Gui
	if not gui or type(k.Create) ~= "function" then return false end
	ui.root = k.Create("Frame", {
		Name = "PartyFrames", Position = UDim2.new(0, L.X, L.Y, 0), Size = UDim2.fromOffset(L.W, (L.RowH + L.Gap) * L.MaxRows + L.LeaveH),
		BackgroundTransparency = 1, Visible = false, ZIndex = L.Z, Parent = gui,
	}, {
		{ "UIListLayout", { Padding = UDim.new(0, L.Gap), SortOrder = Enum.SortOrder.LayoutOrder } },
	})
	for i = 1, L.MaxRows do
		local row = k.Create("Frame", {
			Name = "Member" .. i, Size = UDim2.fromOffset(L.W, L.RowH), LayoutOrder = i, Visible = false, ZIndex = L.Z,
			BackgroundColor3 = themeColor("Bg", Color3.fromRGB(30, 32, 48)), BackgroundTransparency = 0.25, Parent = ui.root,
		}, {
			{ "UICorner", { CornerRadius = UDim.new(0, 8) } },
		})
		local strip = k.Create("Frame", {
			Name = "Side", Size = UDim2.new(0, L.Strip, 1, 0), BorderSizePixel = 0, ZIndex = L.Z + 1, Parent = row,
		}, { { "UICorner", { CornerRadius = UDim.new(0, 3) } } })
		local name = k.Create("TextLabel", {
			Name = "PlayerName", BackgroundTransparency = 1, Position = UDim2.fromOffset(L.Strip + 6, 2),
			Size = UDim2.new(1, -(L.Strip + 10), 0, L.RowH - L.BarH - 8), TextSize = L.NameSize, Text = "",
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = themeColor("Text", Color3.new(1, 1, 1)), ZIndex = L.Z + 1, Parent = row,
		})
		if type(k.NoTranslate) == "function" then k.NoTranslate(name) end -- A23-179: a player's name stays as it is
		local back = k.Create("Frame", {
			Name = "HPBack", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, L.Strip + 6, 1, -4),
			Size = UDim2.new(1, -(L.Strip + 10), 0, L.BarH), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(20, 20, 26),
			ZIndex = L.Z + 1, Parent = row,
		}, { { "UICorner", { CornerRadius = UDim.new(0, 3) } } })
		local fill = k.Create("Frame", {
			Name = "HP", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = L.Z + 2,
			BackgroundColor3 = themeColor("Good", Color3.fromRGB(90, 210, 110)), Parent = back,
		}, { { "UICorner", { CornerRadius = UDim.new(0, 3) } } })
		ui.rows[i] = { Frame = row, Strip = strip, Name = name, Fill = fill, UserId = 0 }
	end
	if type(k.Button) == "function" then
		ui.leave = k.Button({ Name = "PartyLeave", Text = TXT.Leave or "", TextSize = L.BtnSize, LayoutOrder = 99,
			Size = UDim2.fromOffset(L.LeaveW, L.LeaveH), Color = themeColor("Bad", Color3.fromRGB(150, 60, 60)), ZIndex = L.Z + 1,
			Parent = ui.root }, function() Party.Leave() end)
		ui.leave.Parent = ui.root
	end
	return true
end

-- my party's other members on the rows (leader first as the server sends them)
local function render()
	if not build() then return end
	local i = 0
	for _, id in S.Members do
		if id ~= LocalPlayer.UserId and i < L.MaxRows then
			i += 1
			local row = ui.rows[i]
			local p = Players:GetPlayerByUserId(id)
			row.UserId = id
			row.Name.Text = p and Util.PlayerDisplayName(p) or ""
			row.Strip.BackgroundColor3 = sideColor(p and p:GetAttribute("Faction"))
			row.Frame.Visible = true
		end
	end
	for j = i + 1, L.MaxRows do
		ui.rows[j].Frame.Visible = false
		ui.rows[j].UserId = 0
	end
	ui.root.Visible = S.Id ~= 0 and i > 0
end

-- the HP bars follow each member's Humanoid (characters replicate; nothing asked of the server)
local function stepBars()
	if not ui.root or not ui.root.Visible then return end
	for _, row in ui.rows do
		if row.Frame.Visible then
			local p = Players:GetPlayerByUserId(row.UserId)
			local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local frac = (hum and hum.MaxHealth > 0) and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
			row.Fill.Size = UDim2.fromScale(frac, 1)
		end
	end
end

------------------------------------------------------------------ the invite card
local function hideCard()
	S.Card = nil
	if ui.card then ui.card.Visible = false end
end

local function answer(op)
	local card = S.Card
	hideCard()
	if card then send(op, card.Id) end
end

local function showCard(id, fromId, ttl)
	local k = kit()
	local gui = k and k.Gui
	if not gui or type(k.Create) ~= "function" then return end
	if not ui.card then
		ui.card = k.ArtFrame("PanelCard", {
			Name = "PartyInvite", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, L.CardY, 0),
			Size = UDim2.fromOffset(L.CardW, L.CardH), ZIndex = L.Z + 5, Active = true, Visible = false,
		}, { CornerRadius = UDim.new(0, 12) })
		ui.card.Parent = gui
		ui.cardName = k.Create("TextLabel", {
			Name = "From", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 26), TextSize = 18, Text = "", TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = themeColor("Text", Color3.new(1, 1, 1)), ZIndex = L.Z + 6, Parent = ui.card,
		})
		if type(k.NoTranslate) == "function" then k.NoTranslate(ui.cardName) end -- A23-179: the inviter's name as it is
		if type(k.Button) == "function" then
			local join = k.Button({ Name = "Join", Text = TXT.Join or "", TextSize = L.BtnSize, AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(0.5, -18, 0, 34), Color = themeColor("Good", Color3.fromRGB(60, 140, 80)),
				ZIndex = L.Z + 6, Parent = ui.card }, function() answer("Accept") end)
			join.Parent = ui.card
			local later = k.Button({ Name = "NotNow", Text = TXT.NotNow or "", TextSize = L.BtnSize, AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -10), Size = UDim2.new(0.5, -18, 0, 34), ZIndex = L.Z + 6, Parent = ui.card },
				function() answer("Decline") end)
			later.Parent = ui.card
		end
	end
	local from = Players:GetPlayerByUserId(fromId)
	ui.cardName.Text = from and Util.PlayerDisplayName(from) or ""
	S.Card = { Id = id, Until = os.clock() + ttl }
	ui.card.Visible = true
	-- A23-196: a small pop instead of a line
	local scale = ui.card:FindFirstChild("Pop") or k.Create("UIScale", { Name = "Pop", Parent = ui.card })
	scale.Scale = 0.85
	pcall(function()
		game:GetService("TweenService"):Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

------------------------------------------------------------------ server messages
local function wholeId(v)
	return type(v) == "number" and v == v and v >= 1 and v == math.floor(v)
end

function Party.OnEvent(payload)
	if type(payload) ~= "table" then return end
	local kind = payload.Kind
	if kind == "State" then
		local list = {}
		if type(payload.Members) == "table" then
			for _, id in payload.Members do
				if wholeId(id) and #list < 8 then table.insert(list, id) end
			end
		end
		S.Id = wholeId(payload.Id) and payload.Id or 0
		S.Leader = wholeId(payload.Leader) and payload.Leader or 0
		S.Members = S.Id ~= 0 and list or {}
		render()
	elseif kind == "Invite" then
		if not wholeId(payload.Id) or not wholeId(payload.From) then return end
		local ttl = type(payload.TTL) == "number" and math.clamp(payload.TTL, 1, 120) or 30
		showCard(payload.Id, payload.From, ttl)
	elseif kind == "InviteGone" then
		if S.Card and S.Card.Id == payload.Id then hideCard() end
	end
end

function Party.Init(registry)
	C = registry
end

function Party.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
		local r = folder and folder:WaitForChild("Party", 30)
		if not r then return end
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(Party.OnEvent, payload)
			if not ok then warnThrottled("event: " .. tostring(err)) end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(L.Refresh)
			local ok, err = pcall(function()
				stepBars()
				if S.Card and os.clock() > S.Card.Until then hideCard() end
				if ui.root and ui.root.Visible then render() end -- a member's name / side after they load
			end)
			if not ok then warnThrottled("step: " .. tostring(err)) end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		S.Friends[p.UserId] = nil
	end)
end

return Party
