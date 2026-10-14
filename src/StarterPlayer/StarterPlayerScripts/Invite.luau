-- Invite.luau (게임성 개발 1, SPEC A23-79 #3 "친구 초대 + Go to friend"): Invite.Prompt(source) opens Roblox's own invite
-- window (SocialService:PromptGameInvite) with my UserId as the LaunchData, so the server can tell who invited a friend
-- from the friend's join data (GetJoinData().LaunchData, 게임성 개발 2). No reward for inviting (A23-68). Invite.CanShow()
-- is false while I am knocked out, for FailCalm s after a failed scroll and while the Shop window is open (A23-79: no
-- invite button near a KO, a failed enhance or a purchase) - the buttons (menu, Tab list, goose / war win cards: 이미지
-- 개발's layout) show only while it is true. A friend of mine joining this server fires Invite.FriendJoined(player) and
-- shows one line; Invite.GoTo(player) asks the server to take me there (remote GoToFriend, 게임성 개발 2 - the server keeps
-- the sprout protection and the PvP rules; nothing happens until that remote exists). Presentation + the prompt only.
-- Beta metrics (A23-79, beta_metrics_server_2026-10-08.md; ComeBack.Metric): Invite.Seen(source) when an [Invite a friend]
-- button shows (once a session per source; the buttons' owner calls it), "InvitePrompt" when Roblox's window opened,
-- "InviteSent" = how many friends were picked when it closed (SocialService.GameInvitePromptClosed, 1..50). source =
-- one of Config.Analytics.InviteSources ("Menu" / "PlayerList" / "GooseWin" / "WarWin").
-- Public API: Invite.Init(C), Invite.Start(), Invite.CanShow() -> bool, Invite.Prompt(source?) -> bool (yields:
-- call it from a button's own thread), Invite.Seen(source) -> bool, Invite.Closed(player, recipientIds) -> the count sent
-- or nil, Invite.GoTo(player) -> bool, Invite.FriendJoined (Util.Signal: player),
-- Invite.OnFx(kind, data) (the failed-scroll clock; the offline test drives it), Invite.DefaultLine (true: this module
-- shows the plain 'Your friend … joined!' line; 이미지 개발's friend card sets it false and draws its own from FriendJoined).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local Invite = {}
local C = nil
local TAG = "Invite"

local T = {
	FailCalm = 6, -- s after a failed scroll: no invite button (A23-79)
	ShopWindow = "Shop", -- the Panels window that sells passes (ShopUI): no invite while it is open
	Remote = "GoToFriend", -- the server's "take me to my friend" (게임성 개발 2)
	ToastSeconds = 5,
	-- 2-C #9 the win card (Config.WinCard): approved PanelCard + BtnSecondary, bottom middle above the skill bar
	Card = { W = 320, H = 118, Bottom = 190, Z = 40, BtnW = 240, BtnH = 46, LineH = 34, RoundGrace = 3 },
	-- game text: English only (A23-48), short and easy
	Text = { Joined = "Your friend %s joined!", Message = "Come play Halo & Horns with me!" },
}
local S = { FailAt = -math.huge, Seen = {}, Shown = {} } -- Seen[userId] = that friend's line was shown this session;
-- Shown[source] = that source's button was counted this session

Invite.FriendJoined = Util.Signal.new()
Invite.DefaultLine = true -- false once a friend card (이미지 개발) draws FriendJoined itself: never two lines

local function knockedOut()
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum == nil or hum.Health <= 0
end

function Invite.CanShow()
	if not LocalPlayer or knockedOut() then return false end
	if os.clock() - S.FailAt < T.FailCalm then return false end
	local panels = C and C.Panels
	if type(panels) == "table" and type(panels.CurrentId) == "function" then
		local ok, id = pcall(panels.CurrentId)
		if ok and id == T.ShopWindow then return false end
	end
	return true
end

local function metric(id, arg)
	local cb = C and C.ComeBack
	if type(cb) ~= "table" or type(cb.Metric) ~= "function" then return false end
	local ok, sent = pcall(cb.Metric, id, arg)
	return ok and sent == true
end

-- an [Invite a friend] button is on screen (counted once a session per source)
function Invite.Seen(source)
	if type(source) ~= "string" or S.Shown[source] then return false end
	S.Shown[source] = true
	return metric("InviteSeen", source)
end

-- Roblox's invite window closed (SocialService.GameInvitePromptClosed): friends picked -> "InviteSent"
function Invite.Closed(player, recipientIds)
	if player ~= LocalPlayer or type(recipientIds) ~= "table" or #recipientIds < 1 then return nil end
	local n = math.min(#recipientIds, 50)
	metric("InviteSent", n)
	return n
end

-- Roblox's invite window, my UserId as the LaunchData; false when it may not show (CanShow, CanSendGameInviteAsync)
function Invite.Prompt(source)
	if not Invite.CanShow() then return false end
	local okCan, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, LocalPlayer)
	if not okCan or can ~= true then return false end
	local ok, err = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = T.Text.Message
		options.LaunchData = tostring(LocalPlayer.UserId)
		SocialService:PromptGameInvite(LocalPlayer, options)
	end)
	if not ok then Util.Warn(TAG, "invite (" .. tostring(source) .. ") failed: " .. tostring(err)) end
	if ok and source ~= nil then metric("InvitePrompt", source) end
	return ok
end

-- [Go to friend]: the server decides (sprout protection, PvP); false until its remote exists
function Invite.GoTo(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.Remote)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	local ok = pcall(remote.FireServer, remote, player.UserId)
	return ok
end

-- the failed-scroll clock (Fx "Enhance" { Success = false } comes to me only)
function Invite.OnFx(kind, data)
	if kind == "Enhance" and type(data) == "table" and data.Success == false then S.FailAt = os.clock() end
	if kind == "GooseEnd" then
		local root = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local source = Invite.GooseWin(data, LocalPlayer and LocalPlayer:GetAttribute("Faction"), root and root.Position)
		if source then Invite.WinCard(source) end
	end
end

-- (pure) the goose game's end (Fx GooseEnd { Pos, Winner, Coop }): my faction won and I was near the goose -> "GooseWin"
function Invite.GooseWin(data, faction, myPos)
	local cfg = type(Config.WinCard) == "table" and Config.WinCard or {}
	if type(data) ~= "table" or (faction ~= "Halo" and faction ~= "Horns") or data.Winner ~= faction then return nil end
	if typeof(data.Pos) ~= "Vector3" or typeof(myPos) ~= "Vector3" then return nil end
	if (data.Pos - myPos).Magnitude > (tonumber(cfg.GooseRange) or 120) then return nil end
	return "GooseWin"
end

-- (pure) a crown war round really ended (WarRoundEndsAt moved on while the old end was due: the switch-off case pushes
-- a future end without ending) with my side's blessing, in a fought round (WarMode not "Idle") -> "WarWin"
function Invite.WarWin(oldEndsAt, now, blessing, faction, mode)
	if (faction ~= "Halo" and faction ~= "Horns") or blessing ~= faction or mode == "Idle" then return nil end
	oldEndsAt, now = tonumber(oldEndsAt), tonumber(now)
	if not (oldEndsAt and now) or oldEndsAt <= 0 or oldEndsAt > now + T.Card.RoundGrace then return nil end
	return "WarWin"
end

-- the win card: the win line + [Invite a friend] (Prompt with the source) for Config.WinCard.Seconds; one at a time;
-- only while Invite.CanShow() (no KO, failed scroll or Shop near it). -> the card or nil
function Invite.WinCard(source)
	local cfg = type(Config.WinCard) == "table" and Config.WinCard or nil
	local k = C and C.UIKit
	local text = cfg and type(cfg.Text) == "table" and cfg.Text or {}
	if not cfg or type(k) ~= "table" or not k.Gui or type(text[source]) ~= "string" then return nil end
	if not Invite.CanShow() then return nil end
	if S.Card and S.Card.Parent then S.Card:Destroy() end
	local D = T.Card
	local card = k.ArtFrame("PanelCard", { Name = "WinCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -D.Bottom),
		Size = UDim2.fromOffset(D.W, D.H), ZIndex = D.Z })
	if not card then return nil end
	local line = k.StyledLabel({ Name = "Line", Text = text[source], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(1, -24, 0, D.LineH), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = D.Z + 1 }, "Title")
	if line then line.Parent = card end
	local btn = k.ArtTextButton("BtnSecondary", { Name = "Invite", Text = text.Invite or "", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(D.BtnW, D.BtnH), ZIndex = D.Z + 1 }, function()
		if card.Parent then card:Destroy() end
		task.spawn(Invite.Prompt, source)
	end)
	if btn then btn.Parent = card end
	card.Parent = k.Gui
	S.Card = card
	Invite.Seen(source)
	task.delay(tonumber(cfg.Seconds) or 8, function()
		if card.Parent then card:Destroy() end
	end)
	return card
end

local function onPlayerAdded(player)
	if player == LocalPlayer or S.Seen[player.UserId] then return end
	local ok, friend = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, player.UserId)
	if not ok or friend ~= true or player.Parent ~= Players or S.Seen[player.UserId] then return end
	S.Seen[player.UserId] = true
	Invite.FriendJoined:Fire(player)
	if Invite.DefaultLine ~= true then return end
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Toast) == "function" then
		pcall(kit.Toast, string.format(T.Text.Joined, Util.PlayerDisplayName(player)), "info", T.ToastSeconds)
	end
end

function Invite.Init(registry)
	C = registry
end

function Invite.Start()
	if not LocalPlayer then return end
	Players.PlayerAdded:Connect(function(player) task.spawn(onPlayerAdded, player) end)
	pcall(function()
		SocialService.GameInvitePromptClosed:Connect(function(player, recipientIds)
			pcall(Invite.Closed, player, recipientIds)
		end)
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
				pcall(Invite.OnFx, kind, data)
			end)
		end)
		if not ok then Util.Warn(TAG, "Fx hookup failed: " .. tostring(err)) end
	end)
	task.spawn(function() -- 2-C #9: a crown war round my side won -> the win card
		local ok, err = pcall(function()
			local gs = Net.GameState()
			local last = gs:GetAttribute("WarRoundEndsAt")
			gs:GetAttributeChangedSignal("WarRoundEndsAt"):Connect(function()
				local old = last
				last = gs:GetAttribute("WarRoundEndsAt")
				task.defer(function()
					local source = Invite.WarWin(old, workspace:GetServerTimeNow(), gs:GetAttribute("WarBlessing"),
						LocalPlayer:GetAttribute("Faction"), gs:GetAttribute("WarMode"))
					if source then pcall(Invite.WinCard, source) end
				end)
			end)
		end)
		if not ok then Util.Warn(TAG, "war hookup failed: " .. tostring(err)) end
	end)
end

return Invite
