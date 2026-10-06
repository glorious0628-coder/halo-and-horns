-- AnnounceService.luau : A23-15 "좋은 것 전체 채팅 알림" (design skills_weapons_pets §0-3, P5 name hiding).
-- The server only sends { Key, Args, Grade, Self? } to every client (remote "Announce"); each client formats the line
-- from Config.Announce.Text in its own language and shows it as a TextChatService system message in RBXGeneral.
-- Names are the game nickname (Util.PlayerDisplayName, filtered); a player can hide it (data.HideAnnounceName ->
-- "빛의 기사단 한 명이…"). RareWeapon lines within WindowSeconds of one player are grouped (same or lower grade than
-- the opening line) into one "…좋은 것을 N개 더" line; jackpots, the first +10 and higher grades always show by name.
-- Broadcast(key) sends a server event line with no finder (Config.Announce.Events, e.g. the Pumpkin King) to everyone.
-- PublicName(player, honorific) (BB37) is the name every other server-wide line uses (NotifyAll, board, rankings).
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

-- P5 / BB37: the saved choice first, the mirrored attribute while the data is not loaded
local function isHidden(player)
	local data = getData(player)
	if data ~= nil then return data.HideAnnounceName == true end
	return player:GetAttribute("HideAnnounceName") == true
end

-- BB37: the ONE name for every line that reaches the whole server (NotifyAll lines, the town board, ranking rows).
-- Shown: the game nickname (Util.PlayerDisplayName), + Text.Honorific ("님") when honorific is true. Hidden
-- (data.HideAnnounceName): "<faction> 한 명" (Text.HiddenName) with or without honorific, so "%s이" reads right both
-- ways ("OO님이" / "빛의 기사단 한 명이"). Same-server nametags and the Tab list are not covered (players see each other).
function AnnounceService.PublicName(player, honorific)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return "" end
	local T = A.Text
	if isHidden(player) then
		local id = player:GetAttribute("Faction")
		local f = id ~= "None" and Config.Factions[id] or nil -- no faction yet: "누군가"
		return f and string.format(T.HiddenName, f.Name) or T.Someone
	end
	return Util.PlayerDisplayName(player) .. (honorific == true and T.Honorific or "")
end

-- BB37: true when this player's server-wide lines use "<faction> 한 명" (the bounty line picks its hidden variant)
function AnnounceService.IsHidden(player)
	return typeof(player) == "Instance" and player:IsA("Player") and isHidden(player)
end

local function who(player)
	local hidden = isHidden(player)
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

-- server-wide event line with no finder (Config.Announce.Events[key], e.g. the Pumpkin King): every client gets
-- { Key, Args, Event = true } and shows it at once in its own language. Never grouped and never carries a name.
-- args: optional plain values (numbers / strings / booleans).
function AnnounceService.Broadcast(key, args)
	if type(A) ~= "table" or type(A.Text) ~= "table" or type(A.Text[key]) ~= "string" then return end
	if type(A.Events) ~= "table" or A.Events[key] == nil then return end
	local payload = {}
	if type(args) == "table" then
		for k, v in args do
			local t = type(v)
			if type(k) == "string" and (t == "string" or t == "number" or t == "boolean") then payload[k] = v end
		end
	end
	pcall(function()
		Net.Get("Announce"):FireAllClients({ Key = key, Args = payload, Event = true })
	end)
end

local function onSetName(player, hide, ...)
	if select("#", ...) ~= 0 or type(hide) ~= "boolean" then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "SetAnnounceName", Config.RateLimits.SetAnnounceName or 0.5) then return end
	S.PlayerService.SetStat(player, "HideAnnounceName", hide)
	pcall(Net.Notify, player, hide and A.Text.NameHidden or A.Text.NameShown, "info")
	-- BB10: ranking rows follow the choice at once (every board row is rewritten with the hidden flag)
	local ranking = S.RankingService
	if type(ranking) == "table" and type(ranking.MarkHideChanged) == "function" then
		pcall(ranking.MarkHideChanged, player)
	end
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
