-- Deeds.luau : A23-86 decision 1 - the daily good / naughty deeds ledger (게임성 개발 3, 2026-10-09; contract
-- docs/design/choice_card_server_2026-10-09.md). ONE cap a KST day (Config.DayIndex) for every REPEATED Honor / Infamy
-- change: Config.Deeds.PerDay points (6). Callers (ChoiceCard, later the Finisher card, the board's Kind / Sneaky, the
-- lost items) never touch Honor / Infamy themselves; they call Deeds.Add and show the result. A23-58: my own side
-- +points, the other side -points, never below 0; a rank the lower score loses is reported. Gold paid for something is
-- never a deed (nothing here reads gold). Rewards keep coming when the day is full; only the points stop. No streak.
--   Deeds.Preview(player, side, n?) -> stat, change, mine  what Add would change right now ("None", 0, false = no side)
--   Deeds.Add(player, side, n?)     -> stat, change, mine, down, full  what really changed (side "Good" | "Evil";
--                                      down = a rank was lost; full = my own side's rise was cut by the day's cap)
--   Deeds.Left(player) / Deeds.Used(player)   points still open / used today
--   Deeds.Take(player, n) -> how much of n fits today (booked); the caller adds that much (ScoreBudget-compatible)
-- Save: data.Deeds = { Day, N } (Config.Data.Defaults; a new day starts at 0, repaired on every read).
-- Owner attributes: DeedsToday (points used today), DeedsMax (Config.Deeds.PerDay) - the Q window's "Deeds today 2/6".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Deeds = {}

local TAG = "Deeds"
local S = nil

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function perDay()
	return math.max(0, math.floor(num(Config.Deeds and Config.Deeds.PerDay)))
end

local function points()
	return math.max(0, math.floor(num(Config.Deeds and Config.Deeds.Points, 1)))
end

-- today's booking of this player's save (repaired / reset for a new day); nil without data
local function today(player)
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return nil end
	local b = data.Deeds
	if type(b) ~= "table" then
		b = {}
		data.Deeds = b
	end
	local day = Config.DayIndex(os.time())
	if b.Day ~= day then b.Day, b.N = day, 0 end
	b.N = math.clamp(math.floor(num(b.N)), 0, perDay())
	return b
end

local function publish(player)
	if player.Parent ~= Players then return end
	local b = today(player)
	player:SetAttribute("DeedsMax", perDay())
	player:SetAttribute("DeedsToday", b and b.N or 0)
end

local function factionOf(player)
	local f = player:GetAttribute("Faction")
	if f == "Halo" or f == "Horns" then return f end
	return nil
end

local function statOf(f)
	return f == "Halo" and "Honor" or "Infamy"
end

local function ownStat(player, stat)
	local data = S.PlayerService.GetData(player)
	return math.max(0, math.floor(num(data and data[stat])))
end

local function amount(n)
	n = math.floor(num(n, points()))
	return math.clamp(n, 0, perDay())
end

function Deeds.Left(player)
	local b = today(player)
	if not b then return 0 end
	return math.max(0, perDay() - b.N)
end

function Deeds.Used(player)
	local b = today(player)
	return b and b.N or 0
end

function Deeds.Take(player, n)
	n = math.floor(num(n))
	if n <= 0 then return 0 end
	local b = today(player)
	if not b then return 0 end
	local give = math.min(n, math.max(0, perDay() - b.N))
	b.N += give
	publish(player)
	return give
end

function Deeds.Preview(player, side, n)
	if side ~= "Good" and side ~= "Evil" then return "None", 0, false end
	local f = factionOf(player)
	if not f then return "None", 0, false end
	local stat = statOf(f)
	n = amount(n)
	if (f == "Halo") == (side == "Good") then return stat, math.min(n, Deeds.Left(player)), true end
	return stat, -math.min(ownStat(player, stat), n), false
end

local function rankOf(f, score)
	local _, r = Config.GetTitle(f, f == "Halo" and score or 0, f == "Horns" and score or 0)
	return r
end

function Deeds.Add(player, side, n)
	if side ~= "Good" and side ~= "Evil" then return "None", 0, false, false, false end
	local f = factionOf(player)
	if not f then return "None", 0, false, false, false end
	local stat = statOf(f)
	n = amount(n)
	if n <= 0 then return stat, 0, (f == "Halo") == (side == "Good"), false, false end
	if (f == "Halo") == (side == "Good") then
		local got = Deeds.Take(player, n)
		if got > 0 then S.PlayerService.AddStat(player, stat, got) end
		return stat, got, true, false, got < n
	end
	local have = ownStat(player, stat)
	local take = math.min(have, n)
	local down = false
	if take > 0 then
		S.PlayerService.SetStat(player, stat, have - take)
		down = rankOf(f, have - take) < rankOf(f, have)
	end
	return stat, -take, false, down, false
end

function Deeds.Init(registry)
	S = registry
end

function Deeds.Start()
	S.PlayerService.PlayerReady:Connect(function(player)
		local ok, err = pcall(publish, player)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	task.spawn(function() -- the day turns for a player who stays on: the used points go back to 0
		while true do
			task.wait(math.max(5, num(Config.Deeds and Config.Deeds.CheckInterval, 60)))
			for _, p in Players:GetPlayers() do
				if S.PlayerService.IsReady(p) then
					local ok, err = pcall(publish, p)
					if not ok then Util.Warn(TAG, "day: " .. tostring(err)) end
				end
			end
		end
	end)
	print("[Deeds] started")
end

return Deeds
