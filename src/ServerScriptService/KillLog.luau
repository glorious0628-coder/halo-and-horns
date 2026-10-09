-- KillLog.luau : A23-86 D (content_beyond_10min D) - the monster kill record, kept from the first beta day (a count cannot be
-- filled in later; the sticker book screen comes 11/04). 게임성 개발 3, 2026-10-09; contract
-- docs/design/kill_log_server_2026-10-09.md. Every kill that paid this player (MonsterService.MonsterKilled, not the personal
-- tutorial monsters) adds one to: Total, the hand (M) or auto-combat (A) counter, the golden count, ByKind[monster kind] and
-- ByTier[weapon tier] = { M, A } (auto = the player attribute AutoCombatEnabled at that moment: MonsterKilled carries no
-- auto flag, the same rule as the story's AutoKill). The tables are bounded by the game's own kinds and weapon tiers; every
-- number is a whole number between 0 and 1,000,000,000.
-- Save (additive, Version stays 3): data.KillLog = { Total, M, A, Golden, ByKind = { [kind] = n }, ByTier = { ["0".."8"] = { M, A } } },
-- repaired at PlayerReady. Nothing here gives a reward, a score or a stat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local KillLog = {}

local TAG = "KillLog"
local S = nil
local CAP = 1000000000

local function count(v)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return 0 end
	return math.clamp(math.floor(v), 0, CAP)
end

-- data.KillLog repaired in place: known kinds / tiers only, whole numbers in range
local function record(data)
	local k = data.KillLog
	if type(k) ~= "table" then
		k = {}
		data.KillLog = k
	end
	k.Total, k.M, k.A, k.Golden = count(k.Total), count(k.M), count(k.A), count(k.Golden)
	local kinds = {}
	if type(k.ByKind) == "table" then
		for kind, n in k.ByKind do
			if type(kind) == "string" and Config.MonsterTypes[kind] then kinds[kind] = count(n) end
		end
	end
	k.ByKind = kinds
	local tiers = {}
	if type(k.ByTier) == "table" then
		for key, t in k.ByTier do
			local tier = tonumber(key)
			if type(key) == "string" and tier and tier == math.floor(tier) and tier >= 0 and tier <= Config.MaxWeaponTier and type(t) == "table" then
				tiers[tostring(tier)] = { M = count(t.M), A = count(t.A) }
			end
		end
	end
	k.ByTier = tiers
	return k
end

local function onKilled(player, info)
	if type(info) ~= "table" or info.Personal == true then return end
	if type(info.Kind) ~= "string" or not Config.MonsterTypes[info.Kind] then return end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	local k = record(data)
	local auto = player:GetAttribute("AutoCombatEnabled") == true
	local tier = math.clamp(math.floor(count(player:GetAttribute("WeaponTier"))), 0, Config.MaxWeaponTier)
	local key = tostring(tier)
	local row = k.ByTier[key]
	if not row then
		row = { M = 0, A = 0 }
		k.ByTier[key] = row
	end
	local field = auto and "A" or "M"
	k.Total = math.min(CAP, k.Total + 1)
	k[field] = math.min(CAP, k[field] + 1)
	row[field] = math.min(CAP, row[field] + 1)
	k.ByKind[info.Kind] = math.min(CAP, (k.ByKind[info.Kind] or 0) + 1)
	if info.Golden == true then k.Golden = math.min(CAP, k.Golden + 1) end
end

function KillLog.Init(registry)
	S = registry
end

function KillLog.Start()
	S.MonsterService.MonsterKilled:Connect(function(player, info)
		local ok, err = pcall(onKilled, player, info)
		if not ok then Util.Warn(TAG, "kill: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		if type(data) == "table" then
			local ok, err = pcall(record, data)
			if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
		end
	end)
	print("[KillLog] started")
end

return KillLog
