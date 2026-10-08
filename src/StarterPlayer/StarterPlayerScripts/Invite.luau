-- Invite.luau (게임성 개발 1, SPEC A23-79 #3 "친구 초대 + Go to friend"): Invite.Prompt(source) opens Roblox's own invite
-- window (SocialService:PromptGameInvite) with my UserId as the LaunchData, so the server can tell who invited a friend
-- from the friend's join data (GetJoinData().LaunchData, 게임성 개발 2). No reward for inviting (A23-68). Invite.CanShow()
-- is false while I am knocked out, for FailCalm s after a failed scroll and while the Shop window is open (A23-79: no
-- invite button near a KO, a failed enhance or a purchase) - the buttons (menu, Tab list, goose / war win cards: 이미지
-- 개발's layout) show only while it is true. A friend of mine joining this server fires Invite.FriendJoined(player) and
-- shows one line; Invite.GoTo(player) asks the server to take me there (remote GoToFriend, 게임성 개발 2 - the server keeps
-- the sprout protection and the PvP rules; nothing happens until that remote exists). Presentation + the prompt only.
-- Public API: Invite.Init(C), Invite.Start(), Invite.CanShow() -> bool, Invite.Prompt(source?) -> bool (yields:
-- call it from a button's own thread), Invite.GoTo(player) -> bool, Invite.FriendJoined (Util.Signal: player),
-- Invite.OnFx(kind, data) (the failed-scroll clock; the offline test drives it), Invite.DefaultLine (true: this module
-- shows the plain 'Your friend … joined!' line; 이미지 개발's friend card sets it false and draws its own from FriendJoined).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
	-- game text: English only (A23-48), short and easy
	Text = { Joined = "Your friend %s joined!", Message = "Come play Halo & Horns with me!" },
}
local S = { FailAt = -math.huge, Seen = {} } -- Seen[userId] = true: that friend's line was shown this session

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
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
				pcall(Invite.OnFx, kind, data)
			end)
		end)
		if not ok then Util.Warn(TAG, "Fx hookup failed: " .. tostring(err)) end
	end)
end

return Invite
