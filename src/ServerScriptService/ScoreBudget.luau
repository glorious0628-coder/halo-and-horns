-- ScoreBudget.luau : P9 (docs/design/mmorpg_painpoints_ideas_2026-10-05.md, 게임성 개발 2 2026-10-08): ONE daily cap
-- for every REPEATED Honor / Infamy rise, shared by all such sources (the King Slime finisher card first,
-- docs/design/king_finisher_2026-10-08.md). Config.ScoreBudget.PerDay points a KST day (Config.DayIndex); drops
-- (A23-58 off-side picks) never come here, and the old one-time / PvP sources keep their own rules.
-- Save: data.ScoreBudget = { Day, N } (Config.Data.Defaults; a new day starts at 0, repaired on every read).
--   Left(player)    -> points still open today (0 without data)
--   Take(player, n) -> how much of n fits today (0..n), booked at once; the caller adds that much to the stat
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ScoreBudget = {}
local S = nil

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function perDay()
	return math.max(0, math.floor(num(Config.ScoreBudget and Config.ScoreBudget.PerDay)))
end

-- today's booking of this player's save (repaired / reset for a new day); nil without data
local function today(player)
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return nil end
	local b = data.ScoreBudget
	if type(b) ~= "table" then
		b = {}
		data.ScoreBudget = b
	end
	local day = Config.DayIndex(os.time())
	if b.Day ~= day then
		b.Day, b.N = day, 0
	end
	b.N = math.max(0, math.floor(num(b.N)))
	return b
end

function ScoreBudget.Left(player)
	local b = today(player)
	if not b then return 0 end
	return math.max(0, perDay() - b.N)
end

function ScoreBudget.Take(player, n)
	n = math.floor(num(n))
	if n <= 0 then return 0 end
	local b = today(player)
	if not b then return 0 end
	local give = math.min(n, math.max(0, perDay() - b.N))
	b.N += give
	return give
end

function ScoreBudget.Init(services)
	S = services
end

function ScoreBudget.Start() end

return ScoreBudget
