-- AnnounceService.luau : A23-15 "좋은 것 전체 채팅 알림" (design skills_weapons_pets §0-3, P5 name hiding).
-- The server only sends { Key, Args, Grade, UserId } to every client (remote "Announce"); each client formats the line
-- from Config.Announce.Text in its own language and shows it as a TextChatService system message in RBXGeneral.
-- Names are the game nickname (Util.PlayerDisplayName, filtered); a player can hide it (data.HideAnnounceName ->
-- "빛의 기사단 한 명이…"). One player's announcements within WindowSeconds are grouped: the first goes out at once,
-- the rest become one "…외 N개 더" line when the window ends (no chat spam from a lucky streak).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local AnnounceService = {}
local S = nil
local TAG = "AnnounceService"
local A = Config.Announce
local window = {} -- [player] = { SentAt, Pending = n, Best = gradeRank, Grade, Scheduled }

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function who(player)
	local data = getData(player)
	local hidden = data ~= nil and data.HideAnnounceName == true
	local faction = player:GetAttribute("Faction")
	return {
		Who = hidden and "" or Util.PlayerDisplayName(player),
		Hidden = hidden,
		Faction = type(faction) == "string" and faction or "None",
		Class = (function()
			local ok, c = pcall(S.ClassService.GetClass, player)
			return ok and c or "Warrior"
		end)(),
	}
end

local function send(player, key, args, grade)
	local payload = who(player)
	for k, v in args or {} do payload[k] = v end
	pcall(function()
		Net.Get("Announce"):FireAllClients({ Key = key, Args = payload, Grade = grade, UserId = player.UserId })
	end)
end

local function gradeRank(grade)
	local g = Config.WeaponGrades and Config.WeaponGrades[grade]
	return g and g.Rank or 0
end

-- key: Config.Announce.Text key; args: plain values only (numbers / strings / booleans); grade: Config.WeaponGrades id
function AnnounceService.Announce(player, key, args, grade)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
	if type(A) ~= "table" or type(A.Text) ~= "table" or A.Text[key] == nil then return end
	local now = os.clock()
	local w = window[player]
	if w and now - w.SentAt < A.WindowSeconds then
		w.Pending += 1
		if gradeRank(grade) > w.Best then w.Best, w.Grade = gradeRank(grade), grade end
		if not w.Scheduled then
			w.Scheduled = true
			task.delay(math.max(0, A.WindowSeconds - (now - w.SentAt)), function()
				w.Scheduled = false
				if window[player] ~= w or w.Pending <= 0 or player.Parent ~= Players then return end
				local n = w.Pending
				w.Pending, w.SentAt, w.Best = 0, os.clock(), 0
				send(player, "More", { Count = n }, w.Grade)
			end)
		end
		return
	end
	window[player] = { SentAt = now, Pending = 0, Best = 0, Grade = grade, Scheduled = false }
	send(player, key, args, grade)
end

local function onSetName(player, hide, ...)
	if select("#", ...) ~= 0 or type(hide) ~= "boolean" then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "SetAnnounceName", Config.RateLimits.SetAnnounceName or 0.5) then return end
	S.PlayerService.SetStat(player, "HideAnnounceName", hide)
	pcall(Net.Notify, player, hide and A.Text.NameHidden or A.Text.NameShown, "info")
end

function AnnounceService.Init(registry)
	S = registry
end

function AnnounceService.Start()
	Net.Get("SetAnnounceName").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onSetName, player, ...)
		if not ok then Util.Warn(TAG, "SetAnnounceName: " .. tostring(err)) end
	end)
	Players.PlayerRemoving:Connect(function(player) window[player] = nil end)
	print("[AnnounceService] started")
end

return AnnounceService
