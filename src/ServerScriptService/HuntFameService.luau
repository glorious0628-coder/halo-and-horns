-- HuntFameService.luau : gameplay_plan 2-A #4 (A23-135, user 10/11 "명예·악명은 레벨대 사냥에서도 조금씩"; 게임성 개발 2,
-- 2026-10-13). Honor (Halo) / Infamy (Horns) rise from hunting too, so a child who never fights players still climbs past
-- Squire / Rascal. A monster kill counts Config.HuntFame.Units (a golden one GoldenUnits) when it was in the player's own
-- level zone or a harder one (zone MinLevel >= that of Config.QuestZoneForLevel(level)): a monster far below the player's
-- level counts nothing. Every KillsPerPoint units = Points of the player's own score through PlayerService.GrantFame (ctx
-- Hunt: RankingService puts it on no board - the boards count fair PvP only) and one "Honor +1 from hunting!" line.
-- Neutral / None: nothing (Neutral has its artisan fame). Personal / practice monsters: nothing. The units are saved
-- (data.HuntFame, additive), so they carry over sessions and servers.
--   HuntFameService.Counts(level, zoneId) -> bool   .OnKilled(player, info)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local HuntFameService = {}

local TAG = "HuntFameService"
local S = nil
local H = Config.HuntFame or {}
local STAT = { Halo = "Honor", Horns = "Infamy" }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

-- the level a zone is meant for: Config.HuntFame.ZoneLevel (the fields without a level gate), else its MinLevel
local function zoneMin(zoneId)
	local z = type(zoneId) == "string" and Config.Zones[zoneId] or nil
	if type(z) ~= "table" then return nil end
	local lv = type(H.ZoneLevel) == "table" and H.ZoneLevel[zoneId] or nil
	return num(lv, num(z.MinLevel, 1))
end

-- a kill in the player's own level zone or a harder one (A23-135: a monster far below counts nothing)
function HuntFameService.Counts(level, zoneId)
	local here = zoneMin(zoneId)
	if here == nil then return false end
	local own = zoneMin(Config.QuestZoneForLevel(math.max(1, math.floor(num(level, 1)))))
	return own ~= nil and here >= own
end

function HuntFameService.OnKilled(player, info)
	if H.Enabled ~= true or type(info) ~= "table" then return end
	-- a free rider under the field boss's damage share (info.Minor) counts nothing either. A23-181: a kill shared by
	-- several players counts for the first hitter only (info.First; nil = one player's kill, e.g. an older caller)
	if info.Personal == true or info.Practice == true or info.Minor == true or info.First == false then return end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	local stat = STAT[player:GetAttribute("Faction")]
	if not stat then return end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	if not HuntFameService.Counts(data.Level, info.ZoneId) then return end
	local per = math.max(1, math.floor(num(H.KillsPerPoint, 100)))
	local have = math.max(0, num(data.HuntFame)) + (info.Golden == true and num(H.GoldenUnits, 5) or num(H.Units, 1))
	local whole = math.floor(have / per)
	data.HuntFame = have - whole * per
	if whole <= 0 then return end
	local points = whole * math.max(1, math.floor(num(H.Points, 1)))
	S.PlayerService.GrantFame(player, stat, points, { Hunt = true })
	local line = type(H.Text) == "table" and H.Text[stat] or nil
	if type(line) == "string" then Net.Notify(player, string.format(line, points), "reward", nil, "RankUp") end
end

function HuntFameService.Init(registry)
	S = registry
end

function HuntFameService.Start()
	if H.Enabled ~= true then return end
	local monsters = S.MonsterService
	if type(monsters) == "table" and type(monsters.MonsterKilled) == "table" then
		monsters.MonsterKilled:Connect(function(player, info)
			local ok, err = pcall(HuntFameService.OnKilled, player, info)
			if not ok then Util.Warn(TAG, "MonsterKilled: " .. tostring(err)) end
		end)
	else
		Util.Warn(TAG, "MonsterService.MonsterKilled missing; hunting gives no Honor / Infamy")
	end
	print("[HuntFameService] started")
end

return HuntFameService
