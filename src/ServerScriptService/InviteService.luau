-- InviteService.luau : SPEC A23-79 #3 친구 초대 + Go to friend, the server's part (게임성 개발 3, 2026-10-08; contract
-- docs/design/return_server_2026-10-08.md §3). The client (Invite.luau, game dev 1) opens Roblox's invite window with
-- LaunchData = the inviter's UserId. No reward for inviting, ever (A23-68).
--   * An invite join: player:GetJoinData().LaunchData is a whole UserId that is not the player's own. The first one is
--     kept (data.Invite = { By = inviter UserId, At = os.time() }) and InviteService.InviteJoined(invitee, inviterId,
--     inviter Player or nil) fires (metrics). While inviter and invitee share this server, each minute together counts;
--     at Config.Invite.TogetherMinutes InviteService.PlayedTogether(inviter, invitee) fires once (metrics).
--   * c->s "GoToFriend"(userId): travel to a Roblox friend on this server (or my inviter / my invitee). Ready, alive,
--     Config.RateLimits.GoToFriend. The friend's zone must map to a Config.Travel destination: my own town ("Home"), a
--     field / the Crossroads; a seasonal field goes to Config.Invite.SeasonZone; the other side's town or the outskirts
--     answer with a line. A PvP zone only from Config.PvP.RookieLevel (a sprout is never sent into PvP). Then
--     ZoneService.Travel keeps every travel rule (level gate, fight, grudge sack, kaiju, wanted stars, the channel).
--     InviteService.WentToFriend(player, zoneId) fires on an accepted trip (metrics).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local InviteService = {}
InviteService.InviteJoined = Util.Signal.new() -- (invitee, inviterUserId, inviter: Player?)
InviteService.PlayedTogether = Util.Signal.new() -- (inviter, invitee)
InviteService.WentToFriend = Util.Signal.new() -- (player, zoneId)

local TAG = "InviteService"
local S = nil
local I = Config.Invite or {}
local TXT = I.Text or {}

local T = {
	By = {}, -- [invitee Player] = the inviter's UserId (this session, from the join data)
	Together = {}, -- ["<inviterId>:<inviteeId>"] = minutes both were here (this server)
	Logged = {}, -- ["<inviterId>:<inviteeId>"] = true once PlayedTogether fired
	Friend = {}, -- ["<low>:<high>"] = true / false (IsFriendsWith, cached for the server's life)
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function notify(player, text)
	if type(text) ~= "string" or text == "" then return end
	local ok, err = pcall(Net.Notify, player, text, "bad")
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

-- the inviter's UserId from a join's LaunchData ("12345"), or nil
local function inviterOf(player)
	local ok, join = pcall(player.GetJoinData, player)
	if not ok or type(join) ~= "table" then return nil end
	local raw = join.LaunchData
	if type(raw) ~= "string" or #raw == 0 or #raw > 20 or not string.match(raw, "^%d+$") then return nil end
	local id = tonumber(raw)
	if not id or id < 1 or id ~= math.floor(id) or id == player.UserId then return nil end
	return id
end

local function pairKey(a, b)
	if a > b then a, b = b, a end
	return tostring(a) .. ":" .. tostring(b)
end

-- friends on Roblox (one web call per pair per server), or the invite pair
local function isFriend(player, other)
	if T.By[player] == other.UserId or T.By[other] == player.UserId then return true end
	local key = pairKey(player.UserId, other.UserId)
	if T.Friend[key] == nil then
		local ok, res = pcall(player.IsFriendsWith, player, other.UserId)
		if not ok then return false end -- not cached: asked again next time
		T.Friend[key] = res == true
	end
	return T.Friend[key] == true
end

local function inviteKey(inviterId, invitee)
	return tostring(inviterId) .. ":" .. tostring(invitee.UserId)
end

------------------------------------------------------------------ join
local function onReady(player, data)
	local by = inviterOf(player)
	if not by then return end
	T.By[player] = by
	if type(data) == "table" then
		if type(data.Invite) ~= "table" or type(data.Invite.By) ~= "number" then
			data.Invite = { By = by, At = os.time() } -- the first invite that brought this player is kept
		end
	end
	local inviter = Players:GetPlayerByUserId(by)
	if inviter and not S.PlayerService.IsReady(inviter) then inviter = nil end
	InviteService.InviteJoined:Fire(player, by, inviter)
end

local function onLeaving(player)
	T.By[player] = nil
end

-- every minute: an invite pair on this server together; PlayedTogether once at TogetherMinutes
local function minuteTick()
	for invitee, by in T.By do
		local inviter = Players:GetPlayerByUserId(by)
		if invitee.Parent ~= nil and inviter and S.PlayerService.IsReady(inviter) and S.PlayerService.IsReady(invitee) then
			local key = inviteKey(by, invitee)
			T.Together[key] = (T.Together[key] or 0) + 1
			if T.Together[key] >= num(I.TogetherMinutes, 10) and not T.Logged[key] then
				T.Logged[key] = true
				InviteService.PlayedTogether:Fire(inviter, invitee)
			end
		end
	end
end

------------------------------------------------------------------ Go to friend
-- the travel destination for a friend standing in `zoneId` (nil + the line when there is none for me)
local function destinationFor(player, zoneId)
	local zone = type(zoneId) == "string" and Config.Zones[zoneId] or nil
	if not zone or zoneId == "Outskirts" then return nil, TXT.Away end
	if zone.Season ~= nil then
		zoneId = I.SeasonZone or "SlimeMeadow"
		zone = Config.Zones[zoneId]
	end
	if zone.Town and zone.Faction ~= nil then
		local home = Config.HomeZoneId(player:GetAttribute("Faction"))
		if home ~= zoneId then return nil, TXT.OtherTown end
		return "Home", nil, zoneId
	end
	for _, d in Config.Travel.Destinations do
		if d.Id == zoneId then return zoneId, nil, zoneId end
	end
	return nil, TXT.Away
end

local function onGoToFriend(player, ...)
	if select("#", ...) ~= 1 then return end
	local userId = ...
	if type(userId) ~= "number" or userId ~= userId or userId < 1 or userId ~= math.floor(userId) or userId == player.UserId then
		return
	end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "GoToFriend", num(Config.RateLimits.GoToFriend, 3)) then return end
	if player:GetAttribute("ClassChosen") ~= true then return end -- alive: ZoneService.Travel checks it
	local friend = Players:GetPlayerByUserId(userId)
	if not friend or friend == player or not S.PlayerService.IsReady(friend) then
		notify(player, TXT.NotHere)
		return
	end
	if not isFriend(player, friend) then return end
	local zoneId = S.ZoneService.GetZoneId(friend) or friend:GetAttribute("ZoneId")
	local dest, why, realZone = destinationFor(player, zoneId)
	if not dest then
		notify(player, why)
		return
	end
	local target = Config.Zones[realZone]
	local rookie = num(Config.PvP and Config.PvP.RookieLevel, 15)
	if target and target.PvP == true and num(player:GetAttribute("Level"), 1) < rookie then
		notify(player, string.format(TXT.SproutPvP or "%d", rookie))
		return
	end
	if S.ZoneService.GetZoneId(player) == realZone then
		notify(player, TXT.SameZone)
		return
	end
	S.PlayerService.MarkActive(player)
	local ok, accepted, reason = pcall(S.ZoneService.Travel, player, dest, false)
	if not ok then
		Util.Warn(TAG, "travel: " .. tostring(accepted))
		return
	end
	if not accepted then
		notify(player, reason)
		return
	end
	InviteService.WentToFriend:Fire(player, realZone)
end

function InviteService.Init(registry)
	S = registry
end

function InviteService.Start()
	Net.Get("GoToFriend").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onGoToFriend, player, ...)
		if not ok then Util.Warn(TAG, "GoToFriend: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		local ok, err = pcall(onLeaving, player)
		if not ok then Util.Warn(TAG, "leave: " .. tostring(err)) end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			local ok, err = pcall(minuteTick)
			if not ok then Util.Warn(TAG, "minute: " .. tostring(err)) end
		end
	end)
	print("[InviteService] started")
end

-- the inviter's UserId of a player who came in by an invite this session (nil otherwise)
function InviteService.InvitedBy(player)
	return T.By[player]
end

return InviteService
