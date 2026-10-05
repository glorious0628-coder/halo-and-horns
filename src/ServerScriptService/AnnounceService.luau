-- AnnounceService.luau : A23-15 "좋은 것 전체 채팅 알림" (design skills_weapons_pets §0-3, P5 name hiding).
-- The server only sends { Key, Args, Grade, Self? } to every client (remote "Announce"); each client formats the line
-- from Config.Announce.Text in its own language and shows it as a TextChatService system message in RBXGeneral.
-- Names are the game nickname (Util.PlayerDisplayName, filtered); a player can hide it (data.HideAnnounceName ->
-- "빛의 기사단 한 명이…"). RareWeapon lines within WindowSeconds of one player are grouped (same or lower grade than
-- the opening line) into one "…좋은 것을 N개 더" line; jackpots, the first +10 and higher grades always show by name.
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
local window = {} -- [player] = { SentAt, OpenRank, Pending, Best, Grade, Token }

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

-- everyone gets the line; the finder's copy says Self = true (chat line only, no second toast for them). No UserId
-- is ever sent, so a hidden name cannot be recovered by another client (review of 0db0764).
local function send(player, key, args, grade)
	local payload = who(player)
	for k, v in args or {} do payload[k] = v end
	local msg = { Key = key, Args = payload, Grade = grade }
	local mine = { Key = key, Args = payload, Grade = grade, Self = true }
	pcall(function()
		local remote = Net.Get("Announce")
		for _, p in Players:GetPlayers() do
			remote:FireClient(p, p == player and mine or msg)
		end
	end)
end

local function gradeRank(grade)
	local g = Config.WeaponGrades and Config.WeaponGrades[grade]
	return g and g.Rank or 0
end

-- one table per player: SentAt / OpenRank of the line that opened the window, Pending grouped RareWeapon lines
local function state(player)
	local w = window[player]
	if not w then
		w = { SentAt = -math.huge, OpenRank = 0, Pending = 0, Best = 0, Grade = nil, Token = 0 }
		window[player] = w
	end
	return w
end

local function flush(player, w)
	if w.Pending <= 0 or player.Parent ~= Players then
		w.Pending, w.Best = 0, 0
		return
	end
	local n, grade = w.Pending, w.Grade
	w.Pending, w.Best = 0, 0
	send(player, "More", { Count = n }, grade)
end

-- key: Config.Announce.Text key; args: plain values only (numbers / strings / booleans); grade: Config.WeaponGrades id.
-- Only RareWeapon lines of the same or a lower grade than the line that opened the 10 s window are grouped into one
-- "…좋은 것을 N개 더" line; Jackpot, FirstMax and higher grades always go out at once with their own text.
function AnnounceService.Announce(player, key, args, grade)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
	if type(A) ~= "table" or type(A.Text) ~= "table" or A.Text[key] == nil then return end
	local now = os.clock()
	local w = state(player)
	local rank = gradeRank(grade)
	if key == "RareWeapon" and now - w.SentAt < A.WindowSeconds and rank <= w.OpenRank then
		w.Pending += 1
		if rank > w.Best then w.Best, w.Grade = rank, grade end
		local token = w.Token
		task.delay(math.max(0, A.WindowSeconds - (now - w.SentAt)), function()
			if window[player] == w and w.Token == token then flush(player, w) end
		end)
		return
	end
	flush(player, w) -- anything grouped so far goes out first (never lost when a new window opens)
	w.Token += 1
	w.SentAt, w.OpenRank = now, rank
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
